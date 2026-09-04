defmodule EmailSucks.PhaseZeroTest do
  use EmailSucks.DataCase
  use Oban.Testing, repo: EmailSucks.Repo

  alias EmailSucks.PhaseZero
  alias EmailSucks.PhaseZero.Snapshot

  test "membership is frozen and competing requests reuse the pending snapshot" do
    account_key = Ecto.UUID.generate()
    assert {:ok, first} = PhaseZero.freeze(account_key, ["message-b", "message-a", "message-a"])
    assert {:ok, second} = PhaseZero.freeze(account_key, ["later-arrival"])
    assert first.id == second.id
    assert second.message_ids == ["message-a", "message-b"]
    assert_enqueued(worker: PhaseZero.VerifySnapshot, args: %{snapshot_id: first.id})
    assert length(all_enqueued(worker: PhaseZero.VerifySnapshot)) == 1
  end

  test "rolling back the surrounding transaction removes both snapshot and job" do
    assert {:error, :simulated_crash} =
             Repo.transaction(fn ->
               assert {:ok, _} = PhaseZero.freeze(Ecto.UUID.generate(), ["message-a"])
               Repo.rollback(:simulated_crash)
             end)

    assert Ash.read!(Snapshot, authorize?: false) == []
    assert all_enqueued(worker: PhaseZero.VerifySnapshot) == []
  end

  test "snapshot verification survives duplicate job execution without claiming mail was released" do
    assert {:ok, snapshot} = PhaseZero.freeze(Ecto.UUID.generate(), ["message-a"])
    assert :ok = perform_job(PhaseZero.VerifySnapshot, %{snapshot_id: snapshot.id})
    assert :ok = perform_job(PhaseZero.VerifySnapshot, %{snapshot_id: snapshot.id})
    assert Ash.get!(Snapshot, snapshot.id, authorize?: false).status == :verified
  end

  test "invalid membership creates neither a snapshot nor a job" do
    assert {:error, :invalid_membership} = PhaseZero.freeze(Ecto.UUID.generate(), [""])
    assert Ash.read!(Snapshot, authorize?: false) == []
    assert all_enqueued(worker: PhaseZero.VerifySnapshot) == []
  end

  test "an empty snapshot can still verify a window with no selected mail" do
    assert {:ok, snapshot} = PhaseZero.freeze(Ecto.UUID.generate(), [])
    assert snapshot.message_ids == []
    assert :ok = perform_job(PhaseZero.VerifySnapshot, %{snapshot_id: snapshot.id})
  end

  test "membership cannot be rewritten through SQL after freezing" do
    assert {:ok, snapshot} = PhaseZero.freeze(Ecto.UUID.generate(), ["message-a"])

    assert {:error, %Postgrex.Error{postgres: %{code: :check_violation}}} =
             Repo.query(
               "UPDATE phase_zero_snapshots SET message_ids = ARRAY['later'] WHERE id = $1::text::uuid",
               [snapshot.id]
             )
  end

  test "the database rejects a second pending snapshot even if the coordinator is bypassed" do
    account_key = Ecto.UUID.generate()
    assert {:ok, _} = PhaseZero.freeze(account_key, ["message-a"])

    assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
             Repo.query(
               "INSERT INTO phase_zero_snapshots (account_key, message_ids) VALUES ($1::text::uuid, ARRAY['later'])",
               [account_key]
             )
  end
end
