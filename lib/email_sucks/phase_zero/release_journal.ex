defmodule EmailSucks.PhaseZero.ReleaseJournal do
  @moduledoc """
  Synthetic per-message release journal. No Gmail calls, jobs, or HTTP routes.

  A claim records uncertainty before an external operation could start. Expired
  claims must reconcile provider state, never blindly repeat a write. Tokens fence
  database outcomes only; they cannot cancel a provider request already in flight.
  """
  alias EmailSucks.Repo
  alias EmailSucks.PhaseZero.Recovery

  @lease_seconds 30

  def claim(snapshot_id, now \\ System.system_time(:second)) do
    with_journal(
      snapshot_id,
      fn entries ->
        candidate =
          entries
          |> Enum.sort_by(&elem(&1, 0))
          |> Enum.find(fn {_id, entry} ->
            entry["state"] == "pending" or
              (entry["state"] == "unknown" and entry["lease_until"] <= now)
          end)

        case candidate do
          {id, entry} ->
            token = Ecto.UUID.generate()
            action = if entry["state"] == "unknown", do: :reconcile, else: :apply

            next = %{
              "state" => "unknown",
              "token" => token,
              "lease_until" => now + @lease_seconds
            }

            {%{message_id: id, token: token, action: action}, Map.put(entries, id, next)}

          nil ->
            counts = counts(entries)

            result =
              cond do
                counts.complete? -> :complete
                counts.unknown > 0 -> :busy
                true -> :blocked
              end

            {result, entries}
        end
      end,
      true
    )
  end

  @doc "Record observed provider state. Pending means confirmed still held, not an HTTP timeout."
  def record(snapshot_id, message_id, token, outcome)
      when outcome in [:released, :pending, :unavailable] and is_binary(token) do
    with_journal(snapshot_id, fn entries ->
      case entries[message_id] do
        %{"state" => "unknown", "token" => ^token} ->
          next = %{"state" => Atom.to_string(outcome), "token" => token, "lease_until" => 0}
          {:recorded, Map.put(entries, message_id, next)}

        %{"state" => state, "token" => ^token} ->
          if state == Atom.to_string(outcome),
            do: {:recorded, entries},
            else: Repo.rollback(:stale_claim)

        _ ->
          Repo.rollback(:stale_claim)
      end
    end)
  end

  def status(snapshot_id) do
    with_journal(snapshot_id, fn entries -> {counts(entries), entries} end)
  end

  defp counts(entries) do
    frequencies = Enum.frequencies_by(Map.values(entries), & &1["state"])

    %{
      released: Map.get(frequencies, "released", 0),
      pending: Map.get(frequencies, "pending", 0),
      unknown: Map.get(frequencies, "unknown", 0),
      unavailable: Map.get(frequencies, "unavailable", 0),
      complete?: Map.get(frequencies, "released", 0) == map_size(entries)
    }
  end

  defp with_journal(snapshot_id, fun, normal_only? \\ false) do
    Repo.transaction(fn ->
      account_key =
        case Repo.query!(
               "SELECT account_key::text FROM phase_zero_snapshots WHERE id = $1::text::uuid",
               [snapshot_id]
             ).rows do
          [[key]] -> key
          [] -> Repo.rollback(:snapshot_not_found)
        end

      # Always account then snapshot: recovery and claims share one lock order.
      Recovery.lock!(account_key)
      if normal_only?, do: Recovery.ensure_normal!(account_key)

      # Lock the immutable parent before initialization, including across processes.
      case Repo.query!(
             "SELECT message_ids FROM phase_zero_snapshots WHERE id = $1::text::uuid FOR UPDATE",
             [snapshot_id]
           ).rows do
        [[ids]] ->
          initial =
            Map.new(ids, &{&1, %{"state" => "pending", "token" => nil, "lease_until" => 0}})

          Repo.query!(
            "INSERT INTO phase_zero_release_journals (snapshot_id, entries) VALUES ($1::text::uuid, $2) ON CONFLICT DO NOTHING",
            [snapshot_id, initial]
          )

          [[entries]] =
            Repo.query!(
              "SELECT entries FROM phase_zero_release_journals WHERE snapshot_id = $1::text::uuid",
              [snapshot_id]
            ).rows

          {result, updated} = fun.(entries)

          if updated != entries do
            Repo.query!(
              "UPDATE phase_zero_release_journals SET entries = $2 WHERE snapshot_id = $1::text::uuid",
              [snapshot_id, updated]
            )
          end

          result

        [] ->
          Repo.rollback(:snapshot_not_found)
      end
    end)
  end
end
