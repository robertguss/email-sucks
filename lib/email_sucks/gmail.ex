defmodule EmailSucks.Gmail do
  @moduledoc "Personal Gmail connection. Ecto records here are private authentication infrastructure."
  import Ecto.Query
  alias EmailSucks.Repo
  alias EmailSucks.Gmail.{Account, Controlled, Flow, Google, Vault}

  def configured?, do: Application.get_env(:email_sucks, :gmail) != nil
  defp config, do: Application.fetch_env!(:email_sucks, :gmail)
  defp now, do: System.system_time(:second)
  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)

  def begin_connection, do: Controlled.exclusive(&begin_flow/0)

  defp begin_flow do
    if configured?() do
      Repo.transaction(fn ->
        # Global cap is deliberate for this single-user proof; includes consumed attempts.
        lock(71_401)
        time = now()
        Repo.delete_all(from(f in Flow, where: f.expires_at <= ^time), log: false)

        count =
          Repo.aggregate(from(f in Flow, where: f.created_at > ^(time - 60)), :count, log: false)

        if count >= 10, do: Repo.rollback(:rate_limited)
        {:ok, authorization} = Google.authorize(config())
        browser = Google.random()

        Repo.insert!(
          %Flow{
            id: digest(browser),
            payload: Vault.seal(authorization.session_params, "oauth-flow"),
            created_at: time,
            expires_at: time + 600
          },
          log: false
        )

        {browser, authorization.url}
      end)
      |> case do
        {:ok, {browser, url}} -> {:ok, browser, url}
        error -> error
      end
    else
      {:error, :not_configured}
    end
  end

  def consume_flow(browser) when is_binary(browser) and byte_size(browser) == 43 do
    Repo.transaction(fn ->
      flow =
        Repo.one(
          from(f in Flow,
            where: f.id == ^digest(browser) and not f.consumed and f.expires_at > ^now(),
            lock: "FOR UPDATE"
          ),
          log: false
        )

      unless flow, do: Repo.rollback(:invalid_flow)

      case Vault.open(flow.payload, "oauth-flow") do
        {:ok, session} ->
          flow |> Ecto.Changeset.change(consumed: true, payload: "") |> Repo.update!(log: false)
          session

        _ ->
          Repo.rollback(:invalid_flow)
      end
    end)
  end

  def consume_flow(_), do: {:error, :invalid_flow}

  def finish_connection(browser, params) do
    Controlled.exclusive(fn ->
      with true <- configured?(),
           {:ok, flow} <- consume_flow(browser),
           {:ok, identity, credentials} <- Google.callback(config(), flow, params) do
        connect(identity, credentials)
      else
        false -> {:error, :not_configured}
        error -> error
      end
    end)
  end

  @doc false
  # Called only with a Google-validated identity; not exposed as an API/action.
  def connect(identity, tokens) do
    Controlled.exclusive(fn ->
      previous = Repo.get(Account, "primary", log: false)

      if previous && previous.disconnect_phase == "revoking" do
        # A verified OAuth identity can resume an expired browser session's disconnect.
        # Do not save the new grant: revoking the old token may also revoke new tokens.
        if identity.email == config()[:allowed_email] and identity.subject == previous.subject do
          case finish_disconnect(previous) do
            {:ok, _} -> {:error, :disconnect_completed}
            error -> error
          end
        else
          {:error, :wrong_account}
        end
      else
        connect_account(identity, tokens)
      end
    end)
  end

  defp connect_account(identity, tokens) do
    Repo.transaction(fn ->
      lock(71_402)
      # Serialize this read/write with refresh lease claims as well as other reconnects.
      previous =
        Repo.one(from(a in Account, where: a.id == "primary", lock: "FOR UPDATE"), log: false)

      if identity.email != config()[:allowed_email] or
           (previous && previous.subject != identity.subject),
         do: Repo.rollback(:wrong_account)

      tokens = keep_refresh(tokens, previous)

      unless is_binary(tokens["refresh_token"]) and byte_size(tokens["refresh_token"]) > 0,
        do: Repo.rollback(:missing_refresh_token)

      session = Google.random()

      fields = %{
        subject: identity.subject,
        email: identity.email,
        credentials: Vault.seal(tokens, "gmail-tokens"),
        status: "connected",
        session_digest: digest(session),
        session_expires_at: now() + 28_800,
        checked_at: nil,
        refresh_until: 0,
        revision: if(previous, do: previous.revision + 1, else: 0)
      }

      (previous || %Account{id: "primary"})
      |> Ecto.Changeset.change(fields)
      |> Repo.insert_or_update!(log: false)

      session
    end)
  end

  def account(session) when is_binary(session) and byte_size(session) == 43 do
    if configured?() do
      Repo.one(
        from(a in Account,
          where:
            a.session_digest == ^digest(session) and a.session_expires_at > ^now() and
              a.email == ^config()[:allowed_email]
        ),
        log: false
      )
    end
  end

  def account(_), do: nil

  def logout(session) do
    if account = account(session),
      do:
        Repo.update_all(
          from(a in Account,
            where: a.id == ^account.id and a.session_digest == ^account.session_digest
          ),
          [set: [session_digest: nil, session_expires_at: 0]],
          log: false
        )

    :ok
  end

  def disconnect(session) do
    Controlled.exclusive(fn ->
      case account(session) do
        nil ->
          {:error, :unauthorized}

        %Account{disconnect_phase: "revoking"} = account ->
          finish_disconnect(account)

        account ->
          account
          |> Ecto.Changeset.change(disconnect_phase: "restoring")
          |> Repo.update!(log: false)

          with_access(
            session,
            fn account, tokens ->
              with :ok <- Controlled.restore_for_disconnect(config(), tokens["access_token"]),
                   :ok <-
                     EmailSucks.Gmail.Batch.restore_for_disconnect(
                       config(),
                       tokens["access_token"]
                     ) do
                account =
                  account
                  |> Ecto.Changeset.change(disconnect_phase: "revoking")
                  |> Repo.update!(log: false)

                finish_disconnect(account)
              end
            end,
            true
          )
      end
    end)
  end

  defp finish_disconnect(account) do
    with {:ok, tokens} <- Vault.open(account.credentials, "gmail-tokens"),
         {:ok, outcome} <- Google.revoke(config(), tokens["refresh_token"]) do
      {:ok, _} =
        Repo.transaction(fn ->
          account
          |> Ecto.Changeset.change(
            credentials: "",
            status: "reconnect_required",
            disconnect_phase: nil,
            session_digest: nil,
            session_expires_at: 0,
            checked_at: nil,
            refresh_until: 0,
            revision: account.revision + 1
          )
          |> Repo.update!(log: false)

          Repo.update_all(Flow, [set: [consumed: true, payload: ""]], log: false)
        end)

      {:ok, outcome}
    else
      {:error, :invalid_ciphertext} -> {:error, :reconnect_required}
      error -> error
    end
  end

  def batch_summary(session) do
    if account(session), do: EmailSucks.Gmail.Batch.summary(), else: nil
  end

  def batch(session, action) do
    with_access(session, fn account, tokens ->
      result = EmailSucks.Gmail.Batch.run(config(), tokens["access_token"], action)

      if result in [{:error, :missing_scope}, {:error, :reconnect_required}],
        do: update_current(account, status: "reconnect_required")

      result
    end)
  end

  def controlled_summary(session) do
    if account(session), do: EmailSucks.Gmail.Controlled.summary(), else: nil
  end

  def controlled(session, action, expected_revision \\ nil) do
    with_access(session, fn account, tokens ->
      result =
        if action == "repeat",
          do:
            EmailSucks.Gmail.Controlled.repeat(
              config(),
              tokens["access_token"],
              expected_revision
            ),
          else: EmailSucks.Gmail.Controlled.run(config(), tokens["access_token"], action)

      if result in [{:error, :missing_scope}, {:error, :reconnect_required}],
        do: update_current(account, status: "reconnect_required")

      result
    end)
  end

  def check(session), do: with_access(session, &check_profile/2)

  def recent_messages(session) do
    with_access(session, fn account, tokens ->
      case Google.recent_messages(config(), tokens["access_token"]) do
        {:error, reason} = error when reason in [:reconnect_required, :missing_scope] ->
          update_current(account, status: "reconnect_required")
          error

        result ->
          result
      end
    end)
  end

  def inventory(session) do
    with_access(session, fn account, tokens ->
      case Google.inventory(config(), tokens["access_token"]) do
        {:error, reason} = error
        when reason in [:reconnect_required, :missing_scope, :wrong_account] ->
          update_current(account, status: "reconnect_required")
          error

        result ->
          result
      end
    end)
  end

  defp with_access(session, operation, allow_disconnect \\ false) do
    Controlled.exclusive(fn -> access_operation(session, operation, allow_disconnect) end)
  end

  defp access_operation(session, operation, allow_disconnect) do
    case account(session) do
      %Account{disconnect_phase: phase} when not is_nil(phase) and not allow_disconnect ->
        {:error, :disconnect_pending}

      %Account{status: "connected"} = account ->
        with {:ok, tokens} <- Vault.open(account.credentials, "gmail-tokens"),
             {:ok, account, tokens} <- access(account, tokens) do
          operation.(account, tokens)
        else
          {:error, :invalid_ciphertext} ->
            update_current(account, status: "reconnect_required")
            {:error, :reconnect_required}

          error ->
            error
        end

      nil ->
        {:error, :unauthorized}

      %Account{} ->
        {:error, :reconnect_required}
    end
  end

  defp access(account, tokens) do
    if tokens["expires_at"] <= now() + 60,
      do: refresh(account, tokens),
      else: {:ok, account, tokens}
  end

  defp refresh(account, tokens) do
    query =
      from(a in Account,
        where:
          a.id == ^account.id and a.revision == ^account.revision and a.refresh_until <= ^now()
      )

    {count, _} =
      Repo.update_all(query, [set: [refresh_until: now() + 30], inc: [revision: 1]], log: false)

    if count == 1 do
      leased = %{account | revision: account.revision + 1}

      case Google.refresh(config(), tokens) do
        {:ok, refreshed} ->
          ciphertext = Vault.seal(refreshed, "gmail-tokens")

          case update_current(leased, credentials: ciphertext, refresh_until: 0) do
            1 -> {:ok, %{leased | credentials: ciphertext}, refreshed}
            _ -> {:error, :refresh_in_progress}
          end

        {:error, reason} ->
          fields =
            [refresh_until: 0] ++
              if(reason == :reconnect_required, do: [status: "reconnect_required"], else: [])

          update_current(leased, fields)
          {:error, reason}
      end
    else
      {:error, :refresh_in_progress}
    end
  end

  defp check_profile(account, tokens) do
    case Google.profile(config(), tokens["access_token"]) do
      :ok ->
        update_current(account, checked_at: now())
        :ok

      {:error, reason} = error ->
        if reason in [:reconnect_required, :wrong_account, :missing_scope],
          do: update_current(account, status: "reconnect_required")

        error
    end
  end

  defp update_current(account, fields) do
    {count, _} =
      Repo.update_all(
        from(a in Account, where: a.id == ^account.id and a.revision == ^account.revision),
        [set: fields],
        log: false
      )

    count
  end

  defp keep_refresh(tokens, nil), do: tokens
  defp keep_refresh(tokens, %Account{credentials: ""}), do: tokens

  defp keep_refresh(%{"refresh_token" => refresh} = tokens, _)
       when is_binary(refresh) and byte_size(refresh) > 0, do: tokens

  defp keep_refresh(tokens, previous) do
    case Vault.open(previous.credentials, "gmail-tokens") do
      {:ok, old} -> Map.put(tokens, "refresh_token", old["refresh_token"])
      _ -> Repo.rollback(:invalid_ciphertext)
    end
  end

  defp lock(key), do: Repo.query!("SELECT pg_advisory_xact_lock($1)", [key], log: false)
end
