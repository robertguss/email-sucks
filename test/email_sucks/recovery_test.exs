defmodule EmailSucks.RecoveryTest do
  use EmailSucks.DataCase
  alias EmailSucks.PhaseZero
  alias EmailSucks.PhaseZero.{Recovery, ReleaseJournal}

  test "recovery blocks new snapshots and claims but accepts the result of an in-flight claim" do
    account = Ecto.UUID.generate()
    {:ok, snapshot} = PhaseZero.freeze(account, ["a", "b"])
    {:ok, %{token: token}} = ReleaseJournal.claim(snapshot.id, 100)
    assert {:ok, :stopping} = Recovery.begin(account)
    assert {:error, :recovery_active} = PhaseZero.freeze(account, ["late"])
    assert {:error, :recovery_active} = ReleaseJournal.claim(snapshot.id, 101)
    assert {:error, :recovery_active} = ReleaseJournal.claim(snapshot.id, 1000)

    assert {:ok, %{stage: :stopping, unknown: 1, restore_ready?: false}} =
             Recovery.status(account)

    assert {:ok, :recorded} = ReleaseJournal.record(snapshot.id, "a", token, :released)
    assert {:ok, %{unknown: 0, restore_ready?: false}} = Recovery.status(account)
    assert {:ok, :interception_disabled} = Recovery.confirm_interception_disabled(account)
    assert {:ok, %{restore_ready?: true}} = Recovery.status(account)
    assert {:error, :recovery_active} = ReleaseJournal.claim(snapshot.id, 1001)
  end

  test "interception confirmation alone cannot declare an unknown operation settled" do
    account = Ecto.UUID.generate()
    {:ok, snapshot} = PhaseZero.freeze(account, ["a"])
    {:ok, _} = ReleaseJournal.claim(snapshot.id, 100)
    {:ok, :stopping} = Recovery.begin(account)
    {:ok, :interception_disabled} = Recovery.confirm_interception_disabled(account)
    assert {:ok, %{unknown: 1, restore_ready?: false}} = Recovery.status(account)
    assert {:ok, :interception_disabled} = Recovery.begin(account)
  end

  test "uninitialized journals do not hide pending snapshot members" do
    account = Ecto.UUID.generate()
    {:ok, _} = PhaseZero.freeze(account, ["a", "b"])
    {:ok, :stopping} = Recovery.begin(account)
    assert {:ok, %{pending: 2, unknown: 0}} = Recovery.status(account)
  end

  test "one account's recovery does not stop another and confirmation requires a recovery" do
    account = Ecto.UUID.generate()
    assert {:error, :recovery_not_started} = Recovery.confirm_interception_disabled(account)
    {:ok, :stopping} = Recovery.begin(account)
    {:ok, other} = PhaseZero.freeze(Ecto.UUID.generate(), ["a"])
    assert {:ok, %{action: :apply}} = ReleaseJournal.claim(other.id, 100)
  end
end
