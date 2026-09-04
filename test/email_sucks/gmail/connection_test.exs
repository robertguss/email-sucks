defmodule EmailSucks.Gmail.ConnectionTest do
  use EmailSucks.DataCase
  alias EmailSucks.Gmail
  alias EmailSucks.Gmail.{Account, Flow, Vault}

  setup do
    old = Application.get_env(:email_sucks, :gmail)

    Application.put_env(:email_sucks, :gmail,
      client_id: "test",
      client_secret: "test-secret",
      allowed_email: "owner@gmail.com",
      redirect_uri: "http://localhost:4000/auth/google/callback",
      vault_key: String.duplicate("k", 64),
      http_options: [plug: {Req.Test, __MODULE__}]
    )

    on_exit(fn ->
      if old,
        do: Application.put_env(:email_sucks, :gmail, old),
        else: Application.delete_env(:email_sucks, :gmail)
    end)

    :ok
  end

  test "inventory requires a valid session and marks revoked or insufficient access for reconnect" do
    Req.Test.stub(__MODULE__, fn _ -> flunk("unauthorized inventory request") end)
    assert {:error, :unauthorized} = Gmail.inventory("invalid-session")
    {:ok, session} = Gmail.connect(identity(), token())

    Req.Test.stub(__MODULE__, fn conn ->
      Plug.Conn.send_resp(conn, 403, "private-provider-error")
    end)

    assert {:error, :missing_scope} = Gmail.inventory(session)
    assert Repo.one!(Account).status == "reconnect_required"
  end

  test "flow is encrypted, browser-bound, one-use and expires" do
    {:ok, browser, _url} = Gmail.begin_connection()
    flow = Repo.one!(Flow)
    refute flow.payload =~ "code_verifier"
    assert {:error, :invalid_flow} = Gmail.consume_flow("another-browser")
    assert {:ok, %{code_verifier: _, nonce: _, state: _}} = Gmail.consume_flow(browser)
    assert {:error, :invalid_flow} = Gmail.consume_flow(browser)
    {:ok, expired, _url} = Gmail.begin_connection()
    Repo.update_all(Flow, set: [expires_at: 0])
    assert {:error, :invalid_flow} = Gmail.consume_flow(expired)
  end

  test "limits authorization attempts even when previous attempts are consumed" do
    for _ <- 1..10 do
      {:ok, browser, _} = Gmail.begin_connection()
      assert {:ok, _} = Gmail.consume_flow(browser)
    end

    assert {:error, :rate_limited} = Gmail.begin_connection()
  end

  test "persists encrypted credentials and pins subject, with revocable server sessions" do
    assert {:ok, session} = Gmail.connect(identity(), token())
    account = Repo.one!(Account)
    refute account.credentials =~ "test-refresh"
    refute account.session_digest == session
    assert Gmail.account(session).subject == "subject"
    assert Gmail.account("unknown") == nil

    assert {:error, :wrong_account} =
             Gmail.connect(%{identity() | subject: "replacement"}, token())

    assert {:error, :wrong_account} =
             Gmail.connect(%{identity() | email: "stranger@gmail.com"}, token())

    Gmail.logout(session)
    assert Gmail.account(session) == nil
  end

  test "reconnect preserves refresh token, rotates session and rejects missing first refresh" do
    assert {:error, :missing_refresh_token} =
             Gmail.connect(identity(), Map.delete(token(), "refresh_token"))

    {:ok, first} = Gmail.connect(identity(), token())
    {:ok, second} = Gmail.connect(identity(), Map.delete(token(), "refresh_token"))
    assert Gmail.account(first) == nil
    assert {:ok, stored} = Vault.open(Gmail.account(second).credentials, "gmail-tokens")
    assert stored["refresh_token"] == "test-refresh"
  end

  test "expired sessions and tampered ciphertext fail closed" do
    {:ok, session} = Gmail.connect(identity(), token())
    Repo.update_all(Account, set: [session_expires_at: 0])
    assert Gmail.account(session) == nil
    assert {:error, :invalid_ciphertext} = Vault.open("corrupted", "gmail-tokens")
    sealed = Vault.seal(token(), "gmail-tokens")
    assert {:error, :invalid_ciphertext} = Vault.open(sealed, "oauth-flow")
  end

  test "unreadable stored credentials expose a reconnect path without sending a request" do
    {:ok, session} = Gmail.connect(identity(), token())
    Repo.update_all(Account, set: [credentials: "corrupted"])
    Req.Test.stub(__MODULE__, fn _ -> flunk("unreadable credentials must never reach Google") end)
    assert {:error, :reconnect_required} = Gmail.check(session)
    assert Gmail.account(session).status == "reconnect_required"
  end

  test "refreshes expired credentials, checks profile, and preserves refresh token" do
    {:ok, session} = Gmail.connect(identity(), %{token() | "expires_at" => 0})

    Req.Test.stub(__MODULE__, fn conn ->
      case conn.request_path do
        "/token" ->
          Req.Test.json(conn, %{
            "access_token" => "new-access",
            "expires_in" => 3600,
            "token_type" => "Bearer"
          })

        "/gmail/v1/users/me/profile" ->
          assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer new-access"]
          Req.Test.json(conn, %{"emailAddress" => "owner@gmail.com", "messagesTotal" => 123})
      end
    end)

    assert :ok = Gmail.check(session)
    account = Gmail.account(session)
    assert account.checked_at > 0
    {:ok, stored} = Vault.open(account.credentials, "gmail-tokens")
    assert stored["refresh_token"] == "test-refresh"
    refute Map.has_key?(stored, "messagesTotal")
  end

  test "invalid grant requires reconnect; temporary failure keeps credentials" do
    {:ok, session} = Gmail.connect(identity(), %{token() | "expires_at" => 0})
    encrypted = Gmail.account(session).credentials
    Req.Test.stub(__MODULE__, fn conn -> Plug.Conn.send_resp(conn, 503, "temporary") end)
    assert {:error, :provider_unavailable} = Gmail.check(session)
    assert Gmail.account(session).credentials == encrypted
    assert Gmail.account(session).status == "connected"

    Req.Test.stub(__MODULE__, fn conn ->
      conn |> Plug.Conn.put_status(400) |> Req.Test.json(%{"error" => "invalid_grant"})
    end)

    assert {:error, :reconnect_required} = Gmail.check(session)
    assert Gmail.account(session).status == "reconnect_required"
  end

  test "refresh lease prevents concurrent exchanges and expired lease is recoverable" do
    {:ok, session} = Gmail.connect(identity(), %{token() | "expires_at" => 0})
    Repo.update_all(Account, set: [refresh_until: System.system_time(:second) + 30])
    Req.Test.stub(__MODULE__, fn _ -> flunk("lease must prevent an exchange") end)
    assert {:error, :refresh_in_progress} = Gmail.check(session)
    Repo.update_all(Account, set: [refresh_until: 0])
    Req.Test.stub(__MODULE__, fn conn -> Plug.Conn.send_resp(conn, 503, "retry later") end)
    assert {:error, :provider_unavailable} = Gmail.check(session)
  end

  test "an in-flight refresh cannot overwrite a newer reconnect" do
    {:ok, session} = Gmail.connect(identity(), %{token() | "expires_at" => 0})

    Req.Test.stub(__MODULE__, fn conn ->
      {:ok, replacement} =
        Gmail.connect(identity(), %{
          token()
          | "access_token" => "reconnected-access",
            "refresh_token" => "reconnected-refresh"
        })

      send(self(), {:replacement, replacement})

      Req.Test.json(conn, %{
        "access_token" => "stale-refresh-result",
        "expires_in" => 3600,
        "token_type" => "Bearer"
      })
    end)

    assert {:error, :refresh_in_progress} = Gmail.check(session)
    assert_receive {:replacement, replacement}
    assert Gmail.account(session) == nil
    {:ok, stored} = Vault.open(Gmail.account(replacement).credentials, "gmail-tokens")
    assert stored["access_token"] == "reconnected-access"
    assert stored["refresh_token"] == "reconnected-refresh"
  end

  defp identity, do: %{subject: "subject", email: "owner@gmail.com"}

  defp token,
    do: %{
      "access_token" => "test-access",
      "refresh_token" => "test-refresh",
      "expires_at" => System.system_time(:second) + 3600
    }
end
