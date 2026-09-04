defmodule EmailSucks.PhaseZero.Recovery do
  @moduledoc """
  Durable account fence for synthetic recovery experiments. No Gmail I/O.

  Confirmation is a fixture assertion, not proof that a Gmail filter was removed.
  Restore-ready means interception was confirmed disabled and recorded operations
  settled; it does not mean mail was restored. No automatic reactivation exists.
  """
  alias EmailSucks.Repo

  def begin(account_key) do
    transaction(account_key, fn ->
      Repo.query!(
        "INSERT INTO phase_zero_recoveries (account_key) VALUES ($1::text::uuid) ON CONFLICT DO NOTHING",
        [account_key]
      )

      stage(account_key)
    end)
  end

  def confirm_interception_disabled(account_key) do
    transaction(account_key, fn ->
      if stage(account_key) == :normal, do: Repo.rollback(:recovery_not_started)

      Repo.query!(
        "UPDATE phase_zero_recoveries SET stage = 'interception_disabled' WHERE account_key = $1::text::uuid",
        [account_key]
      )

      :interception_disabled
    end)
  end

  def status(account_key) do
    transaction(account_key, fn ->
      rows =
        Repo.query!(
          "SELECT s.message_ids, j.entries FROM phase_zero_snapshots s LEFT JOIN phase_zero_release_journals j ON j.snapshot_id = s.id WHERE s.account_key = $1::text::uuid",
          [account_key]
        ).rows

      states =
        Enum.flat_map(rows, fn [ids, entries] ->
          Enum.map(ids, fn id -> get_in(entries || %{}, [id, "state"]) || "pending" end)
        end)

      counts = Enum.frequencies(states)
      current = stage(account_key)
      unknown = Map.get(counts, "unknown", 0)

      %{
        stage: current,
        pending: Map.get(counts, "pending", 0),
        unknown: unknown,
        released: Map.get(counts, "released", 0),
        unavailable: Map.get(counts, "unavailable", 0),
        restore_ready?: current == :interception_disabled and unknown == 0
      }
    end)
  end

  @doc false
  def lock!(account_key) do
    Repo.query!("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))", [account_key])
  end

  @doc false
  def ensure_normal!(account_key) do
    if stage(account_key) != :normal, do: Repo.rollback(:recovery_active)
  end

  defp transaction(account_key, fun) do
    Repo.transaction(fn ->
      lock!(account_key)
      fun.()
    end)
  end

  defp stage(account_key) do
    case Repo.query!(
           "SELECT stage FROM phase_zero_recoveries WHERE account_key = $1::text::uuid",
           [
             account_key
           ]
         ).rows do
      [] -> :normal
      [["stopping"]] -> :stopping
      [["interception_disabled"]] -> :interception_disabled
    end
  end
end
