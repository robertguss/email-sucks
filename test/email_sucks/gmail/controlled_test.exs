defmodule EmailSucks.Gmail.ControlledTest do
  use EmailSucks.DataCase
  alias EmailSucks.Gmail
  alias EmailSucks.Gmail.Controlled

  setup do
    old = Application.get_env(:email_sucks, :gmail)

    Application.put_env(:email_sucks, :gmail,
      allowed_email: "owner@gmail.com",
      vault_key: String.duplicate("k", 64),
      http_options: [plug: {Req.Test, __MODULE__}]
    )

    on_exit(fn ->
      if old,
        do: Application.put_env(:email_sucks, :gmail, old),
        else: Application.delete_env(:email_sucks, :gmail)
    end)

    {:ok, session} =
      Gmail.connect(%{subject: "subject", email: "owner@gmail.com"}, %{
        "access_token" => "test",
        "refresh_token" => "test",
        "expires_at" => System.system_time(:second) + 3600
      })

    Process.put(:labels, ["INBOX", "UNREAD", "STARRED"])
    Process.put(:writes, 0)
    Req.Test.stub(__MODULE__, &provider/1)
    %{session: session}
  end

  test "holds and releases exactly one message, preserving unread and unrelated labels", %{
    session: session
  } do
    assert {:ok, %{state: "held"}} = Gmail.controlled(session, "hold")
    assert Process.get(:labels) |> Enum.sort() == Enum.sort(["Label_test", "UNREAD", "STARRED"])
    assert {:ok, %{state: "released"}} = Gmail.controlled(session, "release")
    assert Enum.sort(Process.get(:labels)) == Enum.sort(["INBOX", "UNREAD", "STARRED"])
    assert {:error, :invalid_transition} = Gmail.controlled(session, "hold")
    assert Process.get(:writes) == 2
  end

  test "ambiguous provider write stays pending and recovery reads back without repeating it", %{
    session: session
  } do
    Process.put(:ambiguous, true)
    assert {:error, :provider_unavailable} = Gmail.controlled(session, "hold")
    assert Repo.one!(Controlled).state == "hold_pending"
    assert {:ok, %{state: "held"}} = Gmail.controlled(session, "recover")
    assert Process.get(:writes) == 1
    assert {:error, :provider_unavailable} = Gmail.controlled(session, "release")
    assert Repo.one!(Controlled).state == "release_pending"
    assert {:ok, %{state: "released"}} = Gmail.controlled(session, "recover")
    assert Process.get(:writes) == 2
  end

  test "interruption before the write leaves durable intent for retry", %{session: session} do
    Process.put(:interrupt, true)
    assert catch_throw(Gmail.controlled(session, "hold")) == :interrupted
    assert Repo.one!(Controlled).state == "hold_pending"
    Process.delete(:interrupt)
    assert {:ok, %{state: "held"}} = Gmail.controlled(session, "recover")
  end

  test "successful response without provider label change is not reported as held", %{
    session: session
  } do
    Process.put(:ignore_write, true)
    assert {:error, :verification_failed} = Gmail.controlled(session, "hold")
    assert Repo.one!(Controlled).state == "hold_pending"
    Process.delete(:ignore_write)
    assert {:ok, %{state: "held"}} = Gmail.controlled(session, "recover")
  end

  test "refuses wrong or ambiguous fixtures before any modification", %{session: session} do
    for field <- [:wrong_subject, :wrong_sender, :wrong_recipient, :duplicate] do
      Process.put(field, true)
      assert {:error, :fixture_mismatch} = Gmail.controlled(session, "hold")
      assert Repo.one(Controlled) == nil
      assert Process.get(:writes) == 0
      Process.delete(field)
    end
  end

  test "ambiguous label creation is resolved by name on retry", %{session: session} do
    Process.put(:label_missing, true)
    assert {:error, :provider_unavailable} = Gmail.controlled(session, "hold")
    assert Repo.one(Controlled) == nil
    assert Process.get(:writes) == 0
    assert {:ok, %{state: "held"}} = Gmail.controlled(session, "hold")
    assert Process.get(:label_creations) == 1
  end

  test "release overrides an interrupted hold and completed verification does not rehold external edits",
       %{session: session} do
    Process.put(:interrupt, true)
    assert catch_throw(Gmail.controlled(session, "hold")) == :interrupted
    Process.delete(:interrupt)
    assert {:ok, %{state: "released"}} = Gmail.controlled(session, "release")
    assert Process.get(:writes) == 0
    Process.put(:labels, ["UNREAD"])
    assert {:error, :verification_failed} = Gmail.controlled(session, "recover")
    assert Process.get(:writes) == 0
  end

  test "recovery refuses trashed or missing saved message", %{session: session} do
    assert {:ok, %{state: "held"}} = Gmail.controlled(session, "hold")
    Process.put(:labels, ["TRASH", "Label_test"])
    assert {:error, :fixture_mismatch} = Gmail.controlled(session, "release")
    assert Repo.one!(Controlled).state == "release_pending"
    assert Process.get(:writes) == 1
    Req.Test.stub(__MODULE__, fn conn -> Plug.Conn.send_resp(conn, 404, "private") end)
    assert {:error, :not_found} = Gmail.controlled(session, "recover")
    assert Repo.one!(Controlled).state == "release_pending"
  end

  test "requires authorization and restore-mode configuration", %{session: session} do
    assert {:error, :unauthorized} = Gmail.controlled(nil, "hold")
    Application.delete_env(:email_sucks, :gmail)
    assert {:error, :unauthorized} = Gmail.controlled(session, "hold")
    assert Process.get(:writes) == 0
  end

  defp provider(conn) do
    case {conn.method, conn.request_path} do
      {"GET", "/gmail/v1/users/me/messages"} ->
        ids =
          if Process.get(:duplicate),
            do: [%{"id" => "abc"}, %{"id" => "def"}],
            else: [%{"id" => "abc"}]

        Req.Test.json(conn, %{"messages" => ids})

      {"GET", "/gmail/v1/users/me/messages/abc"} ->
        Req.Test.json(conn, %{
          "id" => "abc",
          "labelIds" => Process.get(:labels),
          "payload" => %{
            "headers" => [
              %{
                "name" => "From",
                "value" =>
                  if(Process.get(:wrong_sender),
                    do: "other@gmail.com",
                    else: "Robert <robertguss@gmail.com>"
                  )
              },
              %{
                "name" => "To",
                "value" =>
                  if(Process.get(:wrong_recipient),
                    do: "other@gmail.com",
                    else: "owner@gmail.com"
                  )
              },
              %{
                "name" => "Subject",
                "value" =>
                  if(Process.get(:wrong_subject),
                    do: "Re: phase0-primary-001",
                    else: "phase0-primary-001"
                  )
              }
            ]
          }
        })

      {"GET", "/gmail/v1/users/me/labels"} ->
        labels =
          if Process.get(:label_missing),
            do: [],
            else: [%{"id" => "Label_test", "name" => "Postman/Controlled-primary-001"}]

        Req.Test.json(conn, %{"labels" => labels})

      {"POST", "/gmail/v1/users/me/labels"} ->
        Process.put(:label_missing, false)
        Process.put(:label_creations, Process.get(:label_creations, 0) + 1)
        Plug.Conn.send_resp(conn, 503, "ambiguous label creation")

      {"POST", "/gmail/v1/users/me/messages/abc/modify"} ->
        assert Repo.one!(Controlled).state in ["hold_pending", "release_pending"]
        if Process.get(:interrupt), do: throw(:interrupted)
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        change = Jason.decode!(body)
        assert Enum.sort(Map.keys(change)) == ["addLabelIds", "removeLabelIds"]
        refute "UNREAD" in (change["addLabelIds"] ++ change["removeLabelIds"])

        if !Process.get(:ignore_write) do
          Process.put(
            :labels,
            Enum.uniq((Process.get(:labels) -- change["removeLabelIds"]) ++ change["addLabelIds"])
          )
        end

        Process.put(:writes, Process.get(:writes) + 1)

        if Process.get(:ambiguous),
          do: Plug.Conn.send_resp(conn, 503, "private error"),
          else: Req.Test.json(conn, %{"id" => "abc"})
    end
  end
end
