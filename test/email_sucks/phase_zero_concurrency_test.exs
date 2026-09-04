defmodule EmailSucks.PhaseZeroConcurrencyTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias EmailSucks.{PhaseZero, Repo}

  test "independent database connections converge on one pending snapshot and one job" do
    account_key = Ecto.UUID.generate()
    parent = self()

    on_exit(fn ->
      Sandbox.unboxed_run(Repo, fn ->
        Repo.query!(
          "DELETE FROM oban_jobs WHERE args->>'snapshot_id' IN (SELECT id::text FROM phase_zero_snapshots WHERE account_key = $1::text::uuid)",
          [account_key]
        )

        Repo.query!("DELETE FROM phase_zero_snapshots WHERE account_key = $1::text::uuid", [
          account_key
        ])
      end)
    end)

    tasks =
      for number <- 1..6 do
        Task.async(fn ->
          Sandbox.unboxed_run(Repo, fn ->
            Repo.transaction(fn ->
              %{rows: [[pid]]} = Repo.query!("SELECT pg_backend_pid()")
              send(parent, {:ready, self(), pid})

              receive do
                :go -> PhaseZero.freeze(account_key, ["fixture-#{number}"])
              after
                5_000 -> raise "concurrency barrier timed out"
              end
            end)
          end)
        end)
      end

    connections =
      for _ <- tasks do
        assert_receive {:ready, process, backend_pid}, 5_000
        {process, backend_pid}
      end

    assert connections |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> length() == 6
    Enum.each(connections, fn {process, _} -> send(process, :go) end)

    snapshots =
      Enum.map(tasks, fn task ->
        assert {:ok, {:ok, snapshot}} = Task.await(task, 10_000)
        snapshot
      end)

    assert snapshots |> Enum.map(& &1.id) |> Enum.uniq() |> length() == 1
    assert snapshots |> Enum.map(& &1.message_ids) |> Enum.uniq() |> length() == 1

    Sandbox.unboxed_run(Repo, fn ->
      %{rows: [[count]]} =
        Repo.query!("SELECT count(*) FROM oban_jobs WHERE args->>'snapshot_id' = $1", [
          hd(snapshots).id
        ])

      assert count == 1
    end)
  end

  test "independent claimants cannot both own the same message" do
    alias EmailSucks.PhaseZero.ReleaseJournal
    parent = self()

    {:ok, snapshot} =
      Sandbox.unboxed_run(Repo, fn -> PhaseZero.freeze(Ecto.UUID.generate(), ["a"]) end)

    on_exit(fn ->
      Sandbox.unboxed_run(Repo, fn ->
        Repo.query!("DELETE FROM oban_jobs WHERE args->>'snapshot_id' = $1", [snapshot.id])
        Repo.query!("DELETE FROM phase_zero_snapshots WHERE id = $1::text::uuid", [snapshot.id])
      end)
    end)

    tasks =
      for _ <- 1..2 do
        Task.async(fn ->
          Sandbox.unboxed_run(Repo, fn ->
            Repo.transaction(fn ->
              %{rows: [[pid]]} = Repo.query!("SELECT pg_backend_pid()")
              send(parent, {:claim_ready, self(), pid})

              receive do
                :go -> ReleaseJournal.claim(snapshot.id, 100)
              after
                5_000 -> raise "claim barrier timed out"
              end
            end)
          end)
        end)
      end

    connections =
      for _ <- tasks do
        assert_receive {:claim_ready, process, pid}, 5_000
        {process, pid}
      end

    assert connections |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> length() == 2
    Enum.each(connections, fn {process, _} -> send(process, :go) end)
    results = Enum.map(tasks, &Task.await(&1, 10_000))
    assert Enum.count(results, &match?({:ok, {:ok, %{message_id: "a"}}}, &1)) == 1
    assert Enum.count(results, &match?({:ok, {:ok, :busy}}, &1)) == 1
  end

  test "a release waits for uncommitted recovery and cannot slip through its account fence" do
    alias EmailSucks.PhaseZero.{Recovery, ReleaseJournal}
    account = Ecto.UUID.generate()
    parent = self()
    {:ok, snapshot} = Sandbox.unboxed_run(Repo, fn -> PhaseZero.freeze(account, ["a"]) end)

    on_exit(fn ->
      Sandbox.unboxed_run(Repo, fn ->
        Repo.query!("DELETE FROM oban_jobs WHERE args->>'snapshot_id' = $1", [snapshot.id])
        Repo.query!("DELETE FROM phase_zero_snapshots WHERE id = $1::text::uuid", [snapshot.id])

        Repo.query!("DELETE FROM phase_zero_recoveries WHERE account_key = $1::text::uuid", [
          account
        ])
      end)
    end)

    recovery =
      Task.async(fn ->
        Sandbox.unboxed_run(Repo, fn ->
          Repo.transaction(fn ->
            {:ok, :stopping} = Recovery.begin(account)
            send(parent, :recovery_uncommitted)

            receive do
              :commit -> :ok
            after
              5_000 -> raise "recovery barrier timed out"
            end
          end)
        end)
      end)

    assert_receive :recovery_uncommitted, 5_000

    claimant =
      Task.async(fn ->
        Sandbox.unboxed_run(Repo, fn ->
          Repo.transaction(fn ->
            %{rows: [[pid]]} = Repo.query!("SELECT pg_backend_pid()")
            send(parent, {:release_connection, pid})
            result = ReleaseJournal.claim(snapshot.id, 100)
            send(parent, {:claim_result, result})
            result
          end)
        end)
      end)

    assert_receive {:release_connection, pid}, 5_000

    waiting =
      Enum.reduce_while(1..100, false, fn _, _ ->
        locked =
          Sandbox.unboxed_run(Repo, fn ->
            Repo.query!("SELECT wait_event_type = 'Lock' FROM pg_stat_activity WHERE pid = $1", [
              pid
            ]).rows == [[true]]
          end)

        if locked do
          {:halt, true}
        else
          Process.sleep(10)
          {:cont, false}
        end
      end)

    assert waiting
    send(recovery.pid, :commit)
    assert {:ok, :ok} = Task.await(recovery, 5_000)
    assert_receive {:claim_result, {:error, :recovery_active}}, 5_000
    assert {:error, :rollback} = Task.await(claimant, 5_000)
    assert {:ok, %{unknown: 0}} = Sandbox.unboxed_run(Repo, fn -> Recovery.status(account) end)
  end

  test "scheduled and manual claims on separate connections share one active delivery" do
    alias EmailSucks.PhaseZero.Scheduling
    account = Ecto.UUID.generate()
    parent = self()

    Sandbox.unboxed_run(Repo, fn ->
      {:ok, _} = Scheduling.plan(account, 1, ~D[2026-09-04], ~T[09:00:00], "Etc/UTC")
    end)

    on_exit(fn ->
      Sandbox.unboxed_run(Repo, fn ->
        for table <- [
              "phase_zero_manual_receipts",
              "phase_zero_occurrences",
              "phase_zero_delivery_runs",
              "phase_zero_schedules"
            ] do
          Repo.query!("DELETE FROM " <> table <> " WHERE account_key = $1::text::uuid", [account])
        end

        Repo.query!(
          "DELETE FROM oban_jobs WHERE args->>'snapshot_id' IN (SELECT id::text FROM phase_zero_snapshots WHERE account_key = $1::text::uuid)",
          [account]
        )

        Repo.query!("DELETE FROM phase_zero_snapshots WHERE account_key = $1::text::uuid", [
          account
        ])
      end)
    end)

    tasks =
      for mode <- [:scheduled, :manual] do
        Task.async(fn ->
          Sandbox.unboxed_run(Repo, fn ->
            Repo.transaction(fn ->
              %{rows: [[pid]]} = Repo.query!("SELECT pg_backend_pid()")
              send(parent, {:scheduler_ready, self(), pid})

              receive do
                :go ->
                  if mode == :scheduled,
                    do: Scheduling.claim_due(account, 2_000_000_000, ["a"]),
                    else: Scheduling.check_now(account, "click", ["b"])
              after
                5_000 -> raise "scheduling barrier timed out"
              end
            end)
          end)
        end)
      end

    connections =
      for _ <- tasks do
        assert_receive {:scheduler_ready, process, pid}, 5_000
        {process, pid}
      end

    assert connections |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> length() == 2
    Enum.each(connections, fn {process, _} -> send(process, :go) end)

    runs =
      Enum.map(tasks, fn task ->
        assert {:ok, {:ok, run}} = Task.await(task, 5_000)
        run
      end)

    assert runs |> Enum.map(& &1.id) |> Enum.uniq() |> length() == 1
    assert runs |> Enum.map(& &1.snapshot_id) |> Enum.uniq() |> length() == 1
  end
end
