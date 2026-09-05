defmodule EmailSucks.Gmail.HistoryProbeTest do
  use EmailSucks.DataCase, async: false
  alias EmailSucks.{Repo, Gmail.Controlled, Gmail.Batch, Gmail.HistoryProbe}
  @config [http_options: [plug: {Req.Test, __MODULE__}]]

  setup do
    Repo.insert!(%EmailSucks.Gmail.Account{
      id: "primary",
      subject: "test",
      email: "owner@gmail.com",
      credentials: "private"
    })

    Repo.insert!(%Controlled{
      id: "primary",
      message_id: "m1",
      label_id: "Label_single",
      state: "released",
      repeat_revision: 3
    })

    Repo.insert!(%Batch{
      id: "primary",
      state: "released",
      repeat_revision: 4,
      label_id: "Label_test",
      entries: Map.new(["m2", "m3", "m4"], &{&1, %{"state" => "released", "error" => nil}})
    })

    :ok
  end

  test "freezes membership before reads and atomically catches up a changed known member" do
    before = sources()

    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert Repo.get!(HistoryProbe, "primary").message_ids == ["m1", "m2", "m3", "m4"]

      case Path.basename(conn.request_path) do
        "profile" ->
          Process.put(:profile_captured, true)
          Req.Test.json(conn, %{"historyId" => "90"})

        "history" ->
          Process.put(:caught_up, true)

          Req.Test.json(conn, %{
            "historyId" => "1000",
            "history" => [%{"id" => "101", "messages" => [%{"id" => "m1"}, %{"id" => "foreign"}]}]
          })

        id when id in ["m1", "m2", "m3", "m4"] ->
          assert Process.get(:profile_captured), "profile cursor must precede metadata reads"

          Req.Test.json(conn, %{
            "id" => id,
            "labelIds" => if(Process.get(:caught_up), do: ["INBOX"], else: ["UNREAD"])
          })
      end
    end)

    assert {:ok, %{state: "ready", members: 4, available: 4, revision: 1, mode: "full"} = summary} =
             HistoryProbe.run(@config, "t", "sync")

    refute inspect(summary) =~ "m1"
    row = Repo.get!(HistoryProbe, "primary")
    assert row.cursor == "1000"
    assert row.observations["m1"]["labels"] == ["INBOX"]
    assert row.observations["m2"]["labels"] == ["UNREAD"]
    assert sources() == before
    Repo.get!(Controlled, "primary") |> Ecto.Changeset.change(message_id: "new") |> Repo.update!()

    Req.Test.stub(__MODULE__, fn conn ->
      assert Path.basename(conn.request_path) == "history"
      assert URI.decode_query(conn.query_string)["startHistoryId"] == "1000"
      Req.Test.json(conn, %{"historyId" => "2000"})
    end)

    assert {:ok, %{revision: 2, mode: "incremental"}} = HistoryProbe.run(@config, "t", "sync")
    assert Repo.get!(HistoryProbe, "primary").message_ids == ["m1", "m2", "m3", "m4"]
  end

  test "expired cursor falls back once while message404 is unavailable" do
    stub_full()
    assert {:ok, _} = HistoryProbe.run(@config, "t", "sync")

    Req.Test.stub(__MODULE__, fn conn ->
      name = Path.basename(conn.request_path)

      cond do
        name == "history" and URI.decode_query(conn.query_string)["startHistoryId"] == "100" ->
          Plug.Conn.send_resp(conn, 404, "private")

        name == "profile" ->
          Req.Test.json(conn, %{"historyId" => "200"})

        name == "history" ->
          Req.Test.json(conn, %{"historyId" => "300"})

        name == "m1" ->
          Plug.Conn.send_resp(conn, 404, "private")

        true ->
          Req.Test.json(conn, %{"id" => name, "labelIds" => []})
      end
    end)

    assert {:ok, %{available: 3, unavailable: 1, mode: "expired_rescan", revision: 2}} =
             HistoryProbe.run(@config, "t", "sync")

    row = Repo.get!(HistoryProbe, "primary")

    Req.Test.stub(__MODULE__, fn conn ->
      if Path.basename(conn.request_path) == "profile",
        do: Req.Test.json(conn, %{"historyId" => "400"}),
        else: Plug.Conn.send_resp(conn, 404, "private")
    end)

    assert {:error, :history_expired} = HistoryProbe.run(@config, "t", "sync")
    failed = Repo.get!(HistoryProbe, "primary")

    assert Map.take(failed, [:cursor, :observations, :revision, :checked_at, :mode]) ==
             Map.take(row, [:cursor, :observations, :revision, :checked_at, :mode])

    assert HistoryProbe.summary().error == "history_expired"
  end

  test "partial failure retains checkpoint and a rescan repairs it" do
    stub_full()
    assert {:ok, _} = HistoryProbe.run(@config, "t", "sync")
    row = Repo.get!(HistoryProbe, "primary")

    Req.Test.stub(__MODULE__, fn conn ->
      case Path.basename(conn.request_path) do
        "profile" -> Req.Test.json(conn, %{"historyId" => "200"})
        "m1" -> Req.Test.json(conn, %{"id" => "m1", "labelIds" => ["changed"]})
        _ -> Plug.Conn.send_resp(conn, 503, "private")
      end
    end)

    assert {:error, :provider_unavailable} = HistoryProbe.run(@config, "t", "rescan")
    failed = Repo.get!(HistoryProbe, "primary")
    assert failed.cursor == row.cursor
    assert failed.observations == row.observations
    assert failed.revision == 1
    stub_full()

    assert {:ok, %{revision: 2, mode: "rescan", error: nil}} =
             HistoryProbe.run(@config, "t", "rescan")
  end

  test "first failure is retryable and invalid membership/action never requests" do
    Req.Test.stub(__MODULE__, &Plug.Conn.send_resp(&1, 503, "private"))
    assert {:error, :provider_unavailable} = HistoryProbe.run(@config, "t", "sync")
    assert %{state: "pending", members: 4, available: 0, revision: 0} = HistoryProbe.summary()
    stub_full()
    assert {:ok, %{revision: 1}} = HistoryProbe.run(@config, "t", "sync")
    Repo.delete_all(HistoryProbe)
    Repo.get!(Controlled, "primary") |> Ecto.Changeset.change(message_id: "m2") |> Repo.update!()
    Req.Test.stub(__MODULE__, fn _ -> flunk("invalid input reached Gmail") end)
    assert {:error, :fixture_mismatch} = HistoryProbe.run(@config, "t", "sync")
    assert {:error, :invalid_transition} = HistoryProbe.run(@config, "t", "hold")
    assert HistoryProbe.summary().state == "not_started"
  end

  defp stub_full do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"

      case Path.basename(conn.request_path) do
        "profile" -> Req.Test.json(conn, %{"historyId" => "90"})
        "history" -> Req.Test.json(conn, %{"historyId" => "100"})
        id -> Req.Test.json(conn, %{"id" => id, "labelIds" => ["UNREAD"]})
      end
    end)
  end

  defp sources, do: {Repo.get!(Controlled, "primary"), Repo.get!(Batch, "primary")}
end
