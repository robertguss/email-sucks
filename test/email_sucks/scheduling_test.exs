defmodule EmailSucks.SchedulingTest do
  use EmailSucks.DataCase
  alias EmailSucks.PhaseZero.{Scheduling, ReleaseJournal, Recovery}

  defp plan(account, revision, date) do
    Scheduling.plan(account, revision, date, ~T[09:00:00], "Etc/UTC")
  end

  test "occurrence replay preserves its saved resolution and revision edits cancel only unclaimed windows" do
    account = Ecto.UUID.generate()
    {:ok, first} = plan(account, 1, ~D[2026-09-04])
    assert {:ok, ^first} = plan(account, 1, ~D[2026-09-04])
    assert {:ok, :updated} = Scheduling.change_revision(account, 2)
    assert {:error, :stale_revision} = plan(account, 1, ~D[2026-09-05])
    assert {:ok, :nothing_due} = Scheduling.claim_due(account, 2_000_000_000, ["a"])
    {:ok, _} = plan(account, 2, ~D[2026-09-05])
    assert {:ok, %{snapshot_id: _}} = Scheduling.claim_due(account, 2_000_000_000, ["a"])
  end

  test "overdue windows coalesce and repeated claims preserve membership" do
    account = Ecto.UUID.generate()
    {:ok, _} = plan(account, 1, ~D[2026-09-04])
    {:ok, _} = plan(account, 1, ~D[2026-09-05])
    {:ok, run} = Scheduling.claim_due(account, 2_000_000_000, ["a"])
    assert run.occurrence_count == 2
    assert {:ok, ^run} = Scheduling.claim_due(account, 2_000_000_000, ["late"])
    assert {:error, :release_incomplete} = Scheduling.finish(account, run.id)
    {:ok, %{token: token}} = ReleaseJournal.claim(run.snapshot_id, 100)
    {:ok, :recorded} = ReleaseJournal.record(run.snapshot_id, "a", token, :released)
    assert {:ok, :completed} = Scheduling.finish(account, run.id)
    assert {:ok, :completed} = Scheduling.finish(account, run.id)
    assert {:ok, :nothing_due} = Scheduling.claim_due(account, 2_000_000_000, ["late"])
  end

  test "Check Now competes for the same active run and replay does not consume a future window" do
    account = Ecto.UUID.generate()
    {:ok, _} = plan(account, 1, ~D[2026-09-04])
    {:ok, manual} = Scheduling.check_now(account, "click-1", [])
    assert {:ok, ^manual} = Scheduling.claim_due(account, 2_000_000_000, ["a"])
    assert {:ok, :completed} = Scheduling.finish(account, manual.id)
    assert {:ok, replay} = Scheduling.check_now(account, "click-1", ["late"])
    assert replay.id == manual.id
    assert replay.status == "completed"
    {:ok, scheduled} = Scheduling.claim_due(account, 2_000_000_000, ["a"])
    refute scheduled.id == manual.id
  end

  test "recovery blocks scheduling and unavailable delivery cannot complete" do
    account = Ecto.UUID.generate()
    {:ok, run} = Scheduling.check_now(account, "click", ["a"])
    {:ok, %{token: token}} = ReleaseJournal.claim(run.snapshot_id, 100)
    {:ok, :recorded} = ReleaseJournal.record(run.snapshot_id, "a", token, :unavailable)
    assert {:error, :release_incomplete} = Scheduling.finish(account, run.id)
    {:ok, :stopping} = Recovery.begin(account)
    assert {:error, :recovery_active} = Scheduling.check_now(account, "another", ["b"])
    assert {:error, :recovery_active} = Scheduling.claim_due(account, 2_000_000_000, ["b"])
  end

  test "a Check Now request joining scheduled work stays attached after completion" do
    account = Ecto.UUID.generate()
    {:ok, _} = plan(account, 1, ~D[2026-09-04])
    {:ok, scheduled} = Scheduling.claim_due(account, 2_000_000_000, [])
    assert {:ok, ^scheduled} = Scheduling.check_now(account, "joined-click", ["late"])
    {:ok, :completed} = Scheduling.finish(account, scheduled.id)
    {:ok, replay} = Scheduling.check_now(account, "joined-click", ["late"])
    assert replay.id == scheduled.id
  end

  test "a planned future window cannot be released early and claimed windows survive edits" do
    account = Ecto.UUID.generate()
    {:ok, _} = plan(account, 1, ~D[2026-09-04])
    assert {:ok, :nothing_due} = Scheduling.claim_due(account, 0, ["a"])
    {:ok, run} = Scheduling.claim_due(account, 2_000_000_000, ["a"])
    {:ok, :updated} = Scheduling.change_revision(account, 2)
    assert {:ok, ^run} = Scheduling.claim_due(account, 2_000_000_000, ["late"])
  end
end
