defmodule EmailSucks.Gmail.Google do
  @moduledoc "Google OAuth and message boundary. Provider responses and credentials never become UI errors."
  @scope "https://www.googleapis.com/auth/gmail.modify"
  # Google's published discovery document, checked 2026-09-04. Only fixed Google endpoints.
  @discovery %{
    "issuer" => "https://accounts.google.com",
    "authorization_endpoint" => "https://accounts.google.com/o/oauth2/v2/auth",
    "token_endpoint" => "https://oauth2.googleapis.com/token",
    "jwks_uri" => "https://www.googleapis.com/oauth2/v3/certs"
  }

  def authorize(config) do
    config
    |> strategy()
    |> Keyword.put(:nonce, random())
    |> Assent.Strategy.Google.authorize_url()
  end

  def callback(config, session, params) do
    with {:ok, %{user: user, token: token}} <-
           config
           |> strategy()
           |> Keyword.put(:session_params, session)
           |> Assent.Strategy.Google.callback(params),
         {:ok, identity} <- identity(user, config),
         true <- @scope in String.split(Map.get(token, "scope", "")),
         {:ok, token} <- credentials(token) do
      {:ok, identity, token}
    else
      false -> {:error, :missing_scope}
      {:error, :wrong_account} -> {:error, :wrong_account}
      _ -> {:error, :oauth_failed}
    end
  rescue
    # Treat malformed external responses as failures without rendering/logging their contents.
    _ -> {:error, :oauth_failed}
  end

  def refresh(config, previous) do
    form = [
      grant_type: "refresh_token",
      refresh_token: previous["refresh_token"],
      client_id: config[:client_id],
      client_secret: config[:client_secret]
    ]

    case request(config, method: :post, url: @discovery["token_endpoint"], form: form) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        body = Map.put_new(body, "refresh_token", previous["refresh_token"])

        case credentials(body) do
          {:ok, token} -> {:ok, token}
          _ -> {:error, :provider_unavailable}
        end

      {:ok, %{status: 400, body: %{"error" => "invalid_grant"}}} ->
        {:error, :reconnect_required}

      _ ->
        {:error, :provider_unavailable}
    end
  end

  def profile(config, access_token) do
    case request(config,
           method: :get,
           url: "https://gmail.googleapis.com/gmail/v1/users/me/profile",
           headers: [{"authorization", "Bearer " <> access_token}]
         ) do
      {:ok, %{status: 200, body: %{"emailAddress" => email}}} when is_binary(email) ->
        if String.downcase(email) == config[:allowed_email],
          do: :ok,
          else: {:error, :wrong_account}

      {:ok, %{status: 401}} ->
        {:error, :reconnect_required}

      {:ok, %{status: 403, body: body}} ->
        forbidden(body)

      _ ->
        {:error, :provider_unavailable}
    end
  end

  def recent_messages(config, access_token) do
    with {:ok, body} <-
           mail_get(config, access_token, "",
             maxResults: 5,
             labelIds: "INBOX",
             includeSpamTrash: false
           ),
         messages when is_list(messages) <- Map.get(body, "messages", []) do
      messages
      |> Enum.take(5)
      |> Enum.reduce_while({:ok, []}, fn message, {:ok, acc} ->
        case message_metadata(config, access_token, message) do
          {:ok, item} -> {:cont, {:ok, [item | acc]}}
          {:error, :not_found} -> {:cont, {:ok, acc}}
          error -> {:halt, error}
        end
      end)
      |> case do
        {:ok, items} -> {:ok, Enum.reverse(items)}
        error -> error
      end
    else
      {:error, _} = error -> error
      _ -> {:error, :provider_unavailable}
    end
  end

  @doc "Read-only preflight summary. Filter candidates are not proof of app ownership or receiving coverage."
  def inventory(config, access_token) do
    with {:ok, aliases} <-
           api_get(config, access_token, "settings/sendAs",
             fields: "sendAs(sendAsEmail,isPrimary,isDefault,verificationStatus)"
           ),
         {:ok, identities} <- identities(aliases, config),
         {:ok, label_body} <- api_get(config, access_token, "labels", fields: "labels(id,name)"),
         {:ok, labels} <-
           items(label_body, "labels", fn row ->
             is_binary(row["id"]) and is_binary(row["name"])
           end),
         {:ok, filter_body} <-
           api_get(config, access_token, "settings/filters",
             fields: "filter(id,action(addLabelIds,removeLabelIds))"
           ),
         {:ok, filters} <- items(filter_body, "filter", &valid_filter?/1) do
      held_ids = for label <- labels, label["name"] == "Postman/Held", do: label["id"]

      candidates =
        for filter <- filters,
            Enum.any?(get_in(filter, ["action", "addLabelIds"]) || [], &(&1 in held_ids)) do
          %{
            id: filter["id"],
            removes_inbox?: "INBOX" in (get_in(filter, ["action", "removeLabelIds"]) || [])
          }
        end

      {:ok,
       %{
         identities: identities,
         label_count: length(labels),
         filter_count: length(filters),
         held_filter_candidates: candidates
       }}
    end
  end

  defp identities(body, config) do
    with {:ok, rows} <-
           items(body, "sendAs", fn row ->
             is_binary(row["sendAsEmail"]) and String.contains?(row["sendAsEmail"], "@")
           end) do
      primary = Enum.filter(rows, &(&1["isPrimary"] == true))

      case primary do
        [%{"sendAsEmail" => email}] ->
          if String.downcase(email) == config[:allowed_email] do
            {:ok,
             Enum.map(rows, fn row ->
               %{
                 email: String.downcase(row["sendAsEmail"]),
                 primary?: row["isPrimary"] == true,
                 default?: row["isDefault"] == true,
                 verified?: row["verificationStatus"] == "accepted"
               }
             end)}
          else
            {:error, :wrong_account}
          end

        _ ->
          {:error, :provider_unavailable}
      end
    end
  end

  defp valid_filter?(row) do
    action = Map.get(row, "action", %{})

    is_binary(row["id"]) and is_map(action) and
      Enum.all?(["addLabelIds", "removeLabelIds"], fn key ->
        values = Map.get(action, key, [])
        is_list(values) and Enum.all?(values, &is_binary/1)
      end)
  end

  defp items(body, key, valid?) do
    rows = Map.get(body, key, [])

    if is_list(rows) and Enum.all?(rows, &(is_map(&1) and valid?.(&1))),
      do: {:ok, rows},
      else: {:error, :provider_unavailable}
  end

  defp message_metadata(config, token, %{"id" => id}) when is_binary(id) do
    if Regex.match?(~r/\A[a-zA-Z0-9_-]+\z/, id) do
      with {:ok, body} <-
             mail_get(config, token, "/" <> id,
               format: "metadata",
               metadataHeaders: "From",
               metadataHeaders: "Subject",
               fields: "id,internalDate,labelIds,payload/headers"
             ),
           %{"internalDate" => date, "payload" => %{"headers" => headers}} <- body,
           true <- is_binary(date) and is_list(headers),
           {milliseconds, ""} <- Integer.parse(date),
           {:ok, received} <- DateTime.from_unix(milliseconds, :millisecond) do
        header = fn name, fallback ->
          Enum.find_value(headers, fallback, fn
            %{"name" => key, "value" => value} when is_binary(key) and is_binary(value) ->
              if String.downcase(key) == name and String.trim(value) != "",
                do: String.slice(value, 0, 1000)

            _ ->
              nil
          end)
        end

        {:ok,
         %{
           id: id,
           sender: header.("from", "Unknown sender"),
           subject: header.("subject", "(No subject)"),
           received_at: DateTime.to_iso8601(received),
           unread: "UNREAD" in Map.get(body, "labelIds", [])
         }}
      else
        {:error, _} = error -> error
        _ -> {:error, :provider_unavailable}
      end
    else
      {:error, :provider_unavailable}
    end
  end

  defp message_metadata(_, _, _), do: {:error, :provider_unavailable}

  defp mail_get(config, token, path, params),
    do: api_get(config, token, "messages" <> path, params)

  defp api_get(config, token, path, params) do
    url =
      "https://gmail.googleapis.com/gmail/v1/users/me/" <> path <> "?" <> URI.encode_query(params)

    case request(config, method: :get, url: url, headers: [{"authorization", "Bearer " <> token}]) do
      {:ok, %{status: 200, body: body}} when is_map(body) -> {:ok, body}
      {:ok, %{status: 401}} -> {:error, :reconnect_required}
      {:ok, %{status: 403, body: body}} -> forbidden(body)
      {:ok, %{status: 404}} -> {:error, :not_found}
      _ -> {:error, :provider_unavailable}
    end
  end

  @fixture_subject "phase0-primary-001"
  @fixture_sender "robertguss@gmail.com"
  @controlled_label "Postman/Controlled-primary-001"

  def controlled_fixture(config, token) do
    with {:ok, body} <-
           mail_get(config, token, "",
             q: "in:inbox from:#{@fixture_sender} subject:#{@fixture_subject}",
             maxResults: 2
           ),
         %{"messages" => [%{"id" => id}]} <- body,
         false <- Map.has_key?(body, "nextPageToken"),
         {:ok, message} <- controlled_message(config, token, id),
         true <-
           "INBOX" in message["labelIds"] and
             not Enum.any?(["TRASH", "SPAM", "DRAFT"], &(&1 in message["labelIds"])),
         true <-
           header(message, "subject") == @fixture_subject and
             mailbox?(header(message, "from"), @fixture_sender) and
             mailbox?(header(message, "to"), config[:allowed_email]) do
      {:ok, message}
    else
      {:error, _} = error -> error
      _ -> {:error, :fixture_mismatch}
    end
  end

  def controlled_message(config, token, id) do
    if valid_id?(id) do
      with {:ok, body} <-
             mail_get(config, token, "/" <> id,
               format: "metadata",
               metadataHeaders: "From",
               metadataHeaders: "To",
               metadataHeaders: "Subject",
               fields: "id,labelIds,payload/headers"
             ),
           %{"id" => ^id, "labelIds" => labels} when is_list(labels) <- body,
           true <- Enum.all?(labels, &is_binary/1) do
        {:ok, body}
      else
        {:error, _} = error -> error
        _ -> {:error, :provider_unavailable}
      end
    else
      {:error, :fixture_mismatch}
    end
  end

  def controlled_label(config, token) do
    with {:ok, body} <- api_get(config, token, "labels", fields: "labels(id,name)"),
         {:ok, labels} <- items(body, "labels", &(is_binary(&1["id"]) and is_binary(&1["name"]))) do
      case Enum.filter(labels, &(&1["name"] == @controlled_label)) do
        [%{"id" => id}] ->
          if valid_id?(id), do: {:ok, id}, else: {:error, :provider_unavailable}

        [] ->
          # If creation times out, the next attempt resolves the same name before creating.
          with {:ok, %{"id" => id}} <-
                 api_post(config, token, "labels", %{name: @controlled_label}),
               true <- valid_id?(id) do
            {:ok, id}
          else
            {:error, _} = error -> error
            _ -> {:error, :provider_unavailable}
          end

        _ ->
          {:error, :fixture_mismatch}
      end
    end
  end

  def modify_message(config, token, id, add, remove) do
    if valid_id?(id),
      do:
        api_post(config, token, "messages/#{id}/modify", %{
          addLabelIds: add,
          removeLabelIds: remove
        }),
      else: {:error, :fixture_mismatch}
  end

  defp api_post(config, token, path, body) do
    case request(config,
           method: :post,
           url: "https://gmail.googleapis.com/gmail/v1/users/me/" <> path,
           headers: [{"authorization", "Bearer " <> token}],
           json: body
         ) do
      {:ok, %{status: status, body: body}} when status in [200, 201] and is_map(body) ->
        {:ok, body}

      {:ok, %{status: 401}} ->
        {:error, :reconnect_required}

      {:ok, %{status: 403, body: body}} ->
        forbidden(body)

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      _ ->
        {:error, :provider_unavailable}
    end
  end

  defp valid_id?(id), do: is_binary(id) and Regex.match?(~r/\A[a-zA-Z0-9_-]+\z/, id)

  defp header(message, name) do
    headers = get_in(message, ["payload", "headers"])

    if is_list(headers) do
      case Enum.filter(headers, fn
             %{"name" => key} when is_binary(key) -> String.downcase(key) == name
             _ -> false
           end) do
        [%{"value" => value}] when is_binary(value) -> String.trim(value)
        _ -> nil
      end
    end
  end

  defp mailbox?(value, expected) when is_binary(value) and is_binary(expected) do
    value = String.downcase(value)
    value == expected or Regex.match?(~r/\A[^<>,]*<#{Regex.escape(expected)}>\z/, value)
  end

  defp mailbox?(_, _), do: false

  defp forbidden(%{"error" => error}) when is_map(error) do
    details = Map.get(error, "details", [])
    errors = Map.get(error, "errors", [])
    reasons = for row <- List.wrap(details) ++ List.wrap(errors), is_map(row), do: row["reason"]

    cond do
      Enum.any?(reasons, &(&1 in ["SERVICE_DISABLED", "accessNotConfigured"])) ->
        {:error, :api_disabled}

      Enum.any?(reasons, &(&1 in ["ACCESS_TOKEN_SCOPE_INSUFFICIENT", "insufficientPermissions"])) ->
        {:error, :missing_scope}

      true ->
        {:error, :permission_denied}
    end
  end

  defp forbidden(_), do: {:error, :permission_denied}

  def random, do: :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

  defp strategy(config) do
    [
      client_id: Keyword.fetch!(config, :client_id),
      client_secret: Keyword.fetch!(config, :client_secret),
      redirect_uri: Keyword.fetch!(config, :redirect_uri),
      code_verifier: true,
      openid_configuration: @discovery,
      id_token_signed_response_alg: "RS256",
      id_token_ttl_seconds: 600,
      http_adapter: {Assent.HTTPAdapter.Req, http_options(config)},
      authorization_params: [
        scope: "email #{@scope}",
        access_type: "offline",
        prompt: "consent"
      ]
    ]
  end

  defp identity(%{"sub" => subject, "email" => email, "email_verified" => true}, config)
       when is_binary(subject) and byte_size(subject) > 0 and is_binary(email) do
    if String.downcase(email) == config[:allowed_email],
      do: {:ok, %{subject: subject, email: String.downcase(email)}},
      else: {:error, :wrong_account}
  end

  defp identity(_, _), do: {:error, :wrong_account}

  defp credentials(%{"access_token" => access, "expires_in" => ttl, "token_type" => type} = token)
       when is_binary(access) and byte_size(access) > 0 and is_binary(type) and is_integer(ttl) and
              ttl > 0 and
              ttl <= 86_400 do
    if String.downcase(type) == "bearer" do
      {:ok,
       token
       |> Map.take(~w(access_token refresh_token scope))
       |> Map.put("expires_at", System.system_time(:second) + ttl)}
    else
      {:error, :invalid_token}
    end
  end

  defp credentials(_), do: {:error, :invalid_token}

  defp http_options(config) do
    Keyword.merge(
      [retry: false, redirect: false, receive_timeout: 10_000, connect_options: [timeout: 5_000]],
      Keyword.get(config, :http_options, [])
    )
  end

  defp request(config, opts), do: Req.request(Keyword.merge(http_options(config), opts))
end
