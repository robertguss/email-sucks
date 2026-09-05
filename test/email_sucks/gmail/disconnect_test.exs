defmodule EmailSucks.Gmail.DisconnectTest do
  use EmailSucks.DataCase
  alias EmailSucks.Gmail
  alias EmailSucks.Gmail.{Account, Controlled}

  setup do
    old = Application.get_env(:email_sucks, :gmail)

    Application.put_env(:email_sucks, :gmail,
      client_id: "test",
      client_secret: "test",
      redirect_uri: "http://localhost:4000/auth/google/callback",
      allowed_email: "owner@gmail.com",
      vault_key: String.duplicate("k", 64),
      http_options: [plug: {Req.Test, __MODULE__}]
    )

    on_exit(fn ->
      if old,
        do: Application.put_env(:email_sucks, :gmail, old),
        else: Application.delete_env(:email_sucks, :gmail)
    end)

    {:ok, session} = Gmail.connect(identity(), tokens())

    Repo.insert!(%Controlled{
      id: "primary",
      message_id: "fixture",
      label_id: "Label_test",
      state: "held"
    })

    Process.put(:labels, ["Label_test", "UNREAD", "STARRED"])
    Process.put(:revocations, 0)
    Req.Test.stub(__MODULE__, &provider/1)
    %{session: session}
  end

  test "restores and independently verifies before revoking; clears access but keeps recovery record",
       %{session: session} do
    assert {:ok, :revoked} = Gmail.disconnect(session)
    assert Enum.sort(Process.get(:labels)) == Enum.sort(["INBOX", "UNREAD", "STARRED"])
    assert Repo.one!(Controlled).state == "released"
    assert Process.get(:revocations) == 1
    account = Repo.one!(Account)
    assert account.credentials == ""
    assert account.session_digest == nil
    assert Gmail.account(session) == nil
    assert {:error, :unauthorized} = Gmail.disconnect(session)
  end

  test "failed restoration retains credentials and pauses ordinary mailbox operations", %{
    session: session
  } do
    encrypted = Repo.one!(Account).credentials
    Process.put(:restore_fails, true)
    assert {:error, :provider_unavailable} = Gmail.disconnect(session)
    assert Repo.one!(Account).credentials == encrypted
    assert Repo.one!(Account).disconnect_phase == "restoring"
    assert {:error, :disconnect_pending} = Gmail.controlled(session, "hold")
    assert Process.get(:revocations) == 0
    Process.delete(:restore_fails)
    assert {:ok, :revoked} = Gmail.disconnect(session)
  end

  test "unverified provider success does not revoke", %{session: session} do
    Process.put(:ignore_write, true)
    assert {:error, :verification_failed} = Gmail.disconnect(session)
    assert Repo.one!(Account).disconnect_phase == "restoring"
    assert Process.get(:revocations) == 0
  end

  test "ambiguous revoke resumes without Gmail reads or token refresh", %{session: session} do
    Process.put(:revoke_fails, true)
    assert {:error, :revocation_unconfirmed} = Gmail.disconnect(session)
    assert Repo.one!(Account).disconnect_phase == "revoking"
    Process.delete(:revoke_fails)
    Process.put(:deny_mail, true)
    assert {:ok, :revoked} = Gmail.disconnect(session)
  end

  test "interruption before revoke retains committed stage", %{session: session} do
    Process.put(:interrupt, true)
    assert catch_throw(Gmail.disconnect(session)) == :interrupted
    assert Repo.one!(Account).disconnect_phase == "revoking"
    Process.delete(:interrupt)
    Process.put(:deny_mail, true)
    assert {:ok, :revoked} = Gmail.disconnect(session)
  end

  test "expired session can finish pending revocation after verified OAuth identity, then reconnect afresh",
       %{session: session} do
    Process.put(:revoke_fails, true)
    assert {:error, :revocation_unconfirmed} = Gmail.disconnect(session)
    Repo.update_all(Account, set: [session_expires_at: 0])
    Process.delete(:revoke_fails)
    assert {:error, :wrong_account} = Gmail.connect(%{identity() | subject: "other"}, tokens())
    assert {:error, :disconnect_completed} = Gmail.connect(identity(), tokens())
    assert Repo.one!(Account).credentials == ""
    assert {:ok, new_session} = Gmail.connect(identity(), tokens())
    assert Gmail.account(new_session).disconnect_phase == nil
  end

  test "reconnect during failed restoration preserves the disconnect intent", %{session: session} do
    Process.put(:restore_fails, true)
    assert {:error, :provider_unavailable} = Gmail.disconnect(session)
    assert {:ok, new_session} = Gmail.connect(identity(), tokens())
    assert Gmail.account(new_session).disconnect_phase == "restoring"
    Process.delete(:restore_fails)
    assert {:ok, :revoked} = Gmail.disconnect(new_session)
  end

  test "no experiment can disconnect without creating or searching for mail", %{session: session} do
    Repo.delete_all(Controlled)
    Process.put(:deny_mail, true)
    assert {:ok, :revoked} = Gmail.disconnect(session)
  end

  test "invalid saved refresh token is distinguished from confirmed revocation", %{
    session: session
  } do
    Process.put(:invalid_token, true)
    assert {:ok, :already_invalid} = Gmail.disconnect(session)
    assert Repo.one!(Account).credentials == ""
  end

  test "completed disconnect invalidates OAuth flows opened before it", %{session: session} do
    {:ok, browser, _} = Gmail.begin_connection()
    assert {:ok, :revoked} = Gmail.disconnect(session)
    Req.Test.stub(__MODULE__, fn _ -> flunk("old OAuth flow must not exchange credentials") end)
    assert {:error, :invalid_flow} = Gmail.finish_connection(browser, %{})
  end

  test "restore mode or unknown session makes no provider calls", %{session: session} do
    Req.Test.stub(__MODULE__, fn _ -> flunk("unauthorized provider call") end)
    assert {:error, :unauthorized} = Gmail.disconnect(nil)
    Application.delete_env(:email_sucks, :gmail)
    assert {:error, :unauthorized} = Gmail.disconnect(session)
  end

  defp provider(conn) do
    case {conn.method, conn.request_path} do
      {"GET", "/gmail/v1/users/me/messages/fixture"} ->
        refute Process.get(:deny_mail)
        Req.Test.json(conn, %{"id" => "fixture", "labelIds" => Process.get(:labels)})

      {"POST", "/gmail/v1/users/me/messages/fixture/modify"} ->
        refute Process.get(:deny_mail)
        assert Repo.one!(Account).disconnect_phase == "restoring"
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        assert Jason.decode!(body) == %{
                 "addLabelIds" => ["INBOX"],
                 "removeLabelIds" => ["Label_test"]
               }

        cond do
          Process.get(:restore_fails) ->
            Plug.Conn.send_resp(conn, 503, "private")

          Process.get(:ignore_write) ->
            Req.Test.json(conn, %{"id" => "fixture"})

          true ->
            Process.put(:labels, ["INBOX", "UNREAD", "STARRED"])
            Req.Test.json(conn, %{"id" => "fixture"})
        end

      {"POST", "/revoke"} ->
        assert Repo.one!(Account).disconnect_phase == "revoking"
        if row = Repo.one(Controlled), do: assert(row.state == "released")
        assert conn.query_string == ""
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert URI.decode_query(body) == %{"token" => "test-refresh"}
        if Process.get(:interrupt), do: throw(:interrupted)
        Process.put(:revocations, Process.get(:revocations) + 1)

        cond do
          Process.get(:revoke_fails) ->
            Plug.Conn.send_resp(conn, 503, "private")

          Process.get(:invalid_token) ->
            conn |> Plug.Conn.put_status(400) |> Req.Test.json(%{"error" => "invalid_token"})

          true ->
            Plug.Conn.send_resp(conn, 200, "")
        end
    end
  end

  defp identity, do: %{subject: "subject", email: "owner@gmail.com"}

  defp tokens,
    do: %{
      "access_token" => "test-access",
      "refresh_token" => "test-refresh",
      "expires_at" => System.system_time(:second) + 3600
    }
end
