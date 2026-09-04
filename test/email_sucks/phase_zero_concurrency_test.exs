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
end
