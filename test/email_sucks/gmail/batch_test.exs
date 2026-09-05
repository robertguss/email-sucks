defmodule EmailSucks.Gmail.BatchTest do
  use EmailSucks.DataCase
  alias EmailSucks.Gmail

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

    Process.put(:labels, Map.new(1..3, &{Integer.to_string(&1), ["INBOX", "UNREAD", "STARRED"]}))
    Process.put(:writes, [])
    Req.Test.stub(__MODULE__, &provider/1)
    %{session: session}
  end

  test "freezes three IDs, preserves labels, and never discovers new arrivals during release", %{
    session: s
  } do
    assert {:ok, %{state: "held", held: 3}} = Gmail.batch(s, "hold")
    Process.put(:no_search, true)
    Process.put(:labels, Map.put(Process.get(:labels), "new", ["Label_batch", "UNREAD"]))
    assert {:ok, %{state: "released", released: 3}} = Gmail.batch(s, "release")

    for id <- ~w(1 2 3),
        do:
          assert(Enum.sort(Process.get(:labels)[id]) == Enum.sort(["INBOX", "UNREAD", "STARRED"]))

    assert Process.get(:labels)["new"] == ["Label_batch", "UNREAD"]
    assert length(Process.get(:writes)) == 6
    assert {:error, :invalid_transition} = Gmail.batch(s, "hold")
  end

  test "partial response loss retains one pending member and recovery does not repeat its write",
       %{session: s} do
    Process.put(:ambiguous, "2")
    assert {:error, :provider_unavailable} = Gmail.batch(s, "hold")
    assert %{held: 2, pending: 1, total: 3} = Gmail.batch_summary(s)
    assert {:ok, %{held: 3}} = Gmail.batch(s, "recover")
    assert length(Process.get(:writes)) == 3
    assert {:error, :provider_unavailable} = Gmail.batch(s, "release")
    assert %{released: 2, pending: 1} = Gmail.batch_summary(s)
    assert {:ok, %{released: 3}} = Gmail.batch(s, "recover")
    assert length(Process.get(:writes)) == 6
  end

  test "invalid third fixture causes no mail writes or frozen batch", %{session: s} do
    Process.put(:wrong_subject, true)
    assert {:error, :fixture_mismatch} = Gmail.batch(s, "hold")
    assert %{state: "not_started"} = Gmail.batch_summary(s)
    assert Process.get(:writes) == []
  end

  test "disconnect cannot revoke until every batch member is restored", %{session: s} do
    assert {:ok, _} = Gmail.batch(s, "hold")
    Process.put(:missing, "2")
    assert {:error, :not_found} = Gmail.disconnect(s)
    assert %{released: 2, pending: 1} = Gmail.batch_summary(s)
    assert {:error, :disconnect_pending} = Gmail.batch(s, "hold")
    refute Process.get(:revoked, false)
    Process.delete(:missing)
    assert {:ok, :revoked} = Gmail.disconnect(s)
    assert Process.get(:revoked)
  end

  test "completed hold detects external recovery without reholding", %{session: s} do
    assert {:ok, _} = Gmail.batch(s, "hold")
    Process.put(:labels, Map.put(Process.get(:labels), "2", ["INBOX", "UNREAD"]))
    assert {:error, :verification_failed} = Gmail.batch(s, "recover")
    assert length(Process.get(:writes)) == 3
    assert {:ok, %{released: 3}} = Gmail.batch(s, "release")
  end

  defp provider(conn) do
    case {conn.method, conn.request_path} do
      {"GET", "/gmail/v1/users/me/messages"} ->
        refute Process.get(:no_search, false)
        q = URI.decode_query(conn.query_string)["q"]
        [_, n] = Regex.run(~r/phase0-batch-00([123])/, q)
        Req.Test.json(conn, %{"messages" => [%{"id" => n}]})

      {"GET", "/gmail/v1/users/me/labels"} ->
        Req.Test.json(conn, %{
          "labels" => [%{"id" => "Label_batch", "name" => "Postman/Controlled-batch"}]
        })

      {"GET", "/gmail/v1/users/me/messages/" <> id} ->
        if Process.get(:missing) == id do
          Plug.Conn.send_resp(conn, 404, "private")
        else
          Req.Test.json(conn, %{
            "id" => id,
            "labelIds" => Process.get(:labels)[id],
            "payload" => %{
              "headers" => [
                %{"name" => "From", "value" => "robertguss@gmail.com"},
                %{"name" => "To", "value" => "owner@gmail.com"},
                %{
                  "name" => "Subject",
                  "value" =>
                    if(Process.get(:wrong_subject) && id == "3",
                      do: "wrong",
                      else: "phase0-batch-00#{id}"
                    )
                }
              ]
            }
          })
        end

      {"POST", "/gmail/v1/users/me/messages/" <> rest} ->
        [id, "modify"] = String.split(rest, "/")
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        change = Jason.decode!(body)
        refute "UNREAD" in (change["removeLabelIds"] ++ change["addLabelIds"])
        labels = Process.get(:labels)

        Process.put(
          :labels,
          Map.put(
            labels,
            id,
            Enum.uniq((labels[id] -- change["removeLabelIds"]) ++ change["addLabelIds"])
          )
        )

        Process.put(:writes, [id | Process.get(:writes)])

        if Process.get(:ambiguous) == id,
          do: Plug.Conn.send_resp(conn, 503, "lost"),
          else: Req.Test.json(conn, %{"id" => id})

      {"POST", "/revoke"} ->
        for id <- ~w(1 2 3), do: assert("INBOX" in Process.get(:labels)[id])
        Process.put(:revoked, true)
        Plug.Conn.send_resp(conn, 200, "")
    end
  end
end
