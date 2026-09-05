defmodule EmailSucks.Gmail.HistoryDurabilityTest do
  use ExUnit.Case, async: false
  alias Ecto.Adapters.SQL.Sandbox
  alias EmailSucks.{Repo, Gmail.Account, Gmail.Controlled, Gmail.Batch, Gmail.HistoryProbe}
  @config [http_options: [plug: {Req.Test, __MODULE__}]]

  setup do
    :ok = Sandbox.checkout(Repo, sandbox: false)

    Repo.insert!(
      %Account{id: "primary", subject: "test", email: "owner@gmail.com", credentials: "private"},
      log: false
    )

    Repo.insert!(
      %Controlled{
        id: "primary",
        message_id: "m1",
        label_id: "Label_one",
        state: "released",
        repeat_revision: 3
      },
      log: false
    )

    Repo.insert!(
      %Batch{
        id: "primary",
        label_id: "Label_batch",
        state: "released",
        repeat_revision: 4,
        entries: Map.new(["m2", "m3", "m4"], &{&1, %{"state" => "released"}})
      },
      log: false
    )

    on_exit(fn ->
      Sandbox.checkout(Repo, sandbox: false)
      Repo.delete_all(HistoryProbe, log: false)
      Repo.delete_all(Batch, log: false)
      Repo.delete_all(Controlled, log: false)
      Repo.delete_all(Account, log: false)
      Sandbox.checkin(Repo)
    end)

    :ok
  end

  test "death before checkpoint preserves real commits and releases independent connection lock" do
    parent = self()
    stub(false, parent)
    first = blocked_run()
    send(first.pid, :start)
    assert_receive :before_checkpoint, 3000
    pending = Repo.get!(HistoryProbe, "primary", log: false)
    assert pending.message_ids == ["m1", "m2", "m3", "m4"]
    assert pending.cursor == nil
    assert pending.observations == %{}
    assert {:error, :operation_in_progress} = HistoryProbe.run(@config, "t", "sync")
    kill(first)
    stub(true, parent)
    assert {:ok, %{revision: 1}} = retry()
    checkpoint = Repo.get!(HistoryProbe, "primary", log: false)
    assert checkpoint.cursor == "100"
    assert map_size(checkpoint.observations) == 4

    stub(false, parent)
    second = blocked_run()
    send(second.pid, :start)
    assert_receive :before_checkpoint, 3000
    assert Repo.get!(HistoryProbe, "primary", log: false) == checkpoint
    assert Repo.get!(Controlled, "primary", log: false).repeat_revision == 3
    assert Repo.get!(Batch, "primary", log: false).repeat_revision == 4
    kill(second)
    stub(true, parent)
    assert {:ok, %{revision: 2}} = retry()
  end

  defp blocked_run do
    {pid, monitor} =
      spawn_monitor(fn ->
        :ok = Sandbox.checkout(Repo, sandbox: false)

        receive do
          :start -> HistoryProbe.run(@config, "t", "rescan")
        end
      end)

    Req.Test.allow(__MODULE__, self(), pid)
    %{pid: pid, monitor: monitor}
  end

  defp kill(%{pid: pid, monitor: monitor}) do
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^pid, :killed}
  end

  defp retry do
    Enum.reduce_while(1..100, nil, fn _, _ ->
      case HistoryProbe.run(@config, "t", "rescan") do
        {:error, :operation_in_progress} ->
          Process.sleep(10)
          {:cont, nil}

        result ->
          {:halt, result}
      end
    end)
  end

  defp stub(finish, parent) do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"

      case Path.basename(conn.request_path) do
        "profile" ->
          Req.Test.json(conn, %{"historyId" => "90"})

        "history" ->
          unless finish do
            send(parent, :before_checkpoint)

            receive do
              :never -> :ok
            end
          end

          Req.Test.json(conn, %{"historyId" => "100"})

        id when id in ["m1", "m2", "m3", "m4"] ->
          Req.Test.json(conn, %{"id" => id, "labelIds" => ["UNREAD"]})
      end
    end)
  end
end
