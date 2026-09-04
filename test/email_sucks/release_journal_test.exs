defmodule EmailSucks.ReleaseJournalTest do
  use EmailSucks.DataCase
  alias EmailSucks.PhaseZero
  alias EmailSucks.PhaseZero.ReleaseJournal, as: Journal

  test "partial progress survives retries and only frozen members are claimed" do
    {:ok, snapshot} = PhaseZero.freeze(Ecto.UUID.generate(), ["a", "b"])

    assert {:ok, %{message_id: "a", action: :apply, token: first}} =
             Journal.claim(snapshot.id, 100)

    assert {:ok, :recorded} = Journal.record(snapshot.id, "a", first, :released)
    assert {:ok, %{message_id: "b", token: second}} = Journal.claim(snapshot.id, 100)
    assert {:ok, :busy} = Journal.claim(snapshot.id, 100)
    assert {:ok, %{released: 1, unknown: 1, complete?: false}} = Journal.status(snapshot.id)
    assert {:error, :stale_claim} = Journal.record(snapshot.id, "late-arrival", second, :released)
    assert {:ok, :recorded} = Journal.record(snapshot.id, "b", second, :released)
    assert {:ok, :complete} = Journal.claim(snapshot.id, 101)
  end

  test "lost response or worker crash requires reconciliation and fences stale workers" do
    {:ok, snapshot} = PhaseZero.freeze(Ecto.UUID.generate(), ["a"])
    {:ok, %{token: old}} = Journal.claim(snapshot.id, 100)
    assert {:ok, %{action: :reconcile, token: fresh}} = Journal.claim(snapshot.id, 131)
    refute old == fresh
    assert {:error, :stale_claim} = Journal.record(snapshot.id, "a", old, :released)
    assert {:ok, :recorded} = Journal.record(snapshot.id, "a", fresh, :pending)
    assert {:ok, %{action: :apply, token: retry}} = Journal.claim(snapshot.id, 132)
    assert {:ok, :recorded} = Journal.record(snapshot.id, "a", retry, :released)
    assert {:error, :stale_claim} = Journal.record(snapshot.id, "a", fresh, :pending)
    assert {:ok, %{complete?: true}} = Journal.status(snapshot.id)
  end

  test "unavailable source remains an exception rather than successful delivery" do
    {:ok, snapshot} = PhaseZero.freeze(Ecto.UUID.generate(), ["a"])
    {:ok, %{token: token}} = Journal.claim(snapshot.id, 100)
    assert {:ok, :recorded} = Journal.record(snapshot.id, "a", token, :unavailable)
    assert {:ok, :blocked} = Journal.claim(snapshot.id, 200)
    assert {:ok, %{unavailable: 1, complete?: false}} = Journal.status(snapshot.id)
  end

  test "empty batch completes without a provider operation" do
    {:ok, snapshot} = PhaseZero.freeze(Ecto.UUID.generate(), [])
    assert {:ok, :complete} = Journal.claim(snapshot.id, 100)
  end
end
