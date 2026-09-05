defmodule EmailSucks.Gmail.ControlledDurabilityTest do
  # Real commits and independent connections: sandbox rollback cannot prove crash recovery.
  use ExUnit.Case, async: false
  alias EmailSucks.{Gmail, Repo}
  alias EmailSucks.Gmail.{Account, Controlled}
  alias Ecto.Adapters.SQL.Sandbox

  setup do
    :ok = Sandbox.checkout(Repo, sandbox: false)
    old = Application.get_env(:email_sucks, :gmail)

    Application.put_env(:email_sucks, :gmail,
      allowed_email: "owner@gmail.com",
      vault_key: String.duplicate("k", 64),
      http_options: [plug: {Req.Test, __MODULE__}]
    )

    on_exit(fn ->
      Sandbox.checkout(Repo, sandbox: false)
      Repo.delete_all(Controlled, log: false)
      Repo.delete_all(Account, log: false)
      Sandbox.checkin(Repo)

      if old,
        do: Application.put_env(:email_sucks, :gmail, old),
        else: Application.delete_env(:email_sucks, :gmail)
    end)

    :ok
  end

  test "committed intent survives killed request and competing release cannot overtake hold" do
    {:ok, session} =
      Gmail.connect(%{subject: "subject", email: "owner@gmail.com"}, %{
        "access_token" => "test",
        "refresh_token" => "test",
        "expires_at" => System.system_time(:second) + 3600
      })

    {:ok, provider} = Agent.start_link(fn -> %{labels: ["INBOX", "UNREAD"], writes: 0} end)
    parent = self()

    Req.Test.stub(__MODULE__, fn conn ->
      case {conn.method, conn.request_path} do
        {"GET", "/gmail/v1/users/me/messages"} ->
          Req.Test.json(conn, %{"messages" => [%{"id" => "durable"}]})

        {"GET", "/gmail/v1/users/me/messages/durable"} ->
          Req.Test.json(conn, %{
            "id" => "durable",
            "labelIds" => Agent.get(provider, & &1.labels),
            "payload" => %{
              "headers" => [
                %{"name" => "From", "value" => "robertguss@gmail.com"},
                %{"name" => "To", "value" => "owner@gmail.com"},
                %{"name" => "Subject", "value" => "phase0-primary-001"}
              ]
            }
          })

        {"GET", "/gmail/v1/users/me/labels"} ->
          Req.Test.json(conn, %{
            "labels" => [%{"id" => "Label_test", "name" => "Postman/Controlled-primary-001"}]
          })

        {"POST", "/gmail/v1/users/me/messages/durable/modify"} ->
          Agent.update(provider, fn s ->
            %{s | labels: ["Label_test", "UNREAD"], writes: s.writes + 1}
          end)

          send(parent, :provider_applied)

          receive do
            :never_sent -> Req.Test.json(conn, %{})
          end
      end
    end)

    {pid, monitor} =
      spawn_monitor(fn ->
        :ok = Sandbox.checkout(Repo, sandbox: false)

        receive do
          :start -> Gmail.controlled(session, "hold")
        end
      end)

    Req.Test.allow(__MODULE__, self(), pid)
    send(pid, :start)
    assert_receive :provider_applied, 3000
    assert Repo.one!(Controlled).state == "hold_pending"
    assert {:error, :operation_in_progress} = Gmail.controlled(session, "release")
    assert {:error, :operation_in_progress} = Gmail.disconnect(session)
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^pid, :killed}
    assert Repo.one!(Controlled).state == "hold_pending"
    assert {:ok, %{state: "held"}} = recover(session, 100)
    assert Agent.get(provider, & &1.writes) == 1
  end

  test "killed disconnect retains committed revocation intent across connections" do
    {:ok, session} =
      Gmail.connect(%{subject: "subject", email: "owner@gmail.com"}, %{
        "access_token" => "test",
        "refresh_token" => "test",
        "expires_at" => System.system_time(:second) + 3600
      })

    parent = self()

    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.request_path == "/revoke"
      send(parent, :revoking)

      receive do
        :never_sent -> Plug.Conn.send_resp(conn, 200, "")
      end
    end)

    {pid, monitor} =
      spawn_monitor(fn ->
        :ok = Sandbox.checkout(Repo, sandbox: false)

        receive do
          :start -> Gmail.disconnect(session)
        end
      end)

    Req.Test.allow(__MODULE__, self(), pid)
    send(pid, :start)
    assert_receive :revoking, 3000
    assert Repo.one!(Account).disconnect_phase == "revoking"

    assert {:error, :operation_in_progress} =
             Gmail.connect(%{subject: "subject", email: "owner@gmail.com"}, %{})

    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^pid, :killed}
    assert Repo.one!(Account).credentials != ""

    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.request_path == "/revoke"
      conn |> Plug.Conn.put_status(400) |> Req.Test.json(%{"error" => "invalid_token"})
    end)

    assert {:ok, :already_invalid} = retry_disconnect(session, 100)
    assert Repo.one!(Account).credentials == ""
  end

  defp retry_disconnect(session, retries) do
    case Gmail.disconnect(session) do
      {:error, :operation_in_progress} when retries > 0 ->
        receive do
        after
          10 -> retry_disconnect(session, retries - 1)
        end

      result ->
        result
    end
  end

  defp recover(session, retries) do
    case Gmail.controlled(session, "recover") do
      {:error, :operation_in_progress} when retries > 0 ->
        receive do
        after
          10 -> recover(session, retries - 1)
        end

      result ->
        result
    end
  end
end
