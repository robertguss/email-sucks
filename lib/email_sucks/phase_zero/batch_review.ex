defmodule EmailSucks.PhaseZero.BatchReview do
  @moduledoc """
  Synthetic batch-review ledger. Grouping partitions exact snapshot members and
  remains fixed. A conversation is reviewable only after all its selected messages
  are confirmed released. No Gmail read/archive changes or work-item transitions.
  """
  alias EmailSucks.Repo
  alias EmailSucks.PhaseZero.Recovery

  def prepare(snapshot_id, groups) when is_map(groups) do
    with_snapshot(snapshot_id, fn ids ->
      valid? =
        Enum.all?(groups, fn {thread, members} ->
          is_binary(thread) and String.trim(thread) != "" and is_list(members) and members != []
        end)

      unless valid? and Enum.sort(Enum.flat_map(groups, &elem(&1, 1))) == Enum.sort(ids),
        do: Repo.rollback(:invalid_membership)

      normalized = Map.new(groups, fn {thread, members} -> {thread, Enum.sort(members)} end)

      case ledger(snapshot_id) do
        nil ->
          Repo.query!(
            "INSERT INTO phase_zero_batch_reviews (snapshot_id, groups) VALUES ($1::text::uuid, $2)",
            [snapshot_id, normalized]
          )

        [^normalized, _reviewed] ->
          :ok

        _ ->
          Repo.rollback(:membership_frozen)
      end

      :prepared
    end)
  end

  def review(snapshot_id, thread) when is_binary(thread) do
    with_snapshot(snapshot_id, fn _ids ->
      [groups, reviewed] = ledger(snapshot_id) || Repo.rollback(:unprepared_batch)
      members = groups[thread] || Repo.rollback(:item_not_found)
      entries = journal(snapshot_id)
      unless released?(members, entries), do: Repo.rollback(:not_released)

      unless thread in reviewed do
        Repo.query!(
          "UPDATE phase_zero_batch_reviews SET reviewed = array_append(reviewed, $2) WHERE snapshot_id = $1::text::uuid",
          [snapshot_id, thread]
        )
      end

      :reviewed
    end)
  end

  def status(account_key) do
    Repo.transaction(fn ->
      Recovery.lock!(account_key)

      rows =
        Repo.query!(
          "SELECT r.groups, r.reviewed, j.entries FROM phase_zero_snapshots s LEFT JOIN phase_zero_batch_reviews r ON r.snapshot_id = s.id LEFT JOIN phase_zero_release_journals j ON j.snapshot_id = s.id WHERE s.account_key = $1::text::uuid",
          [account_key]
        ).rows

      states =
        Enum.flat_map(rows, fn
          [nil, _, _] ->
            Repo.rollback(:unprepared_batch)

          [groups, reviewed, entries] ->
            Enum.map(groups, fn {thread, members} ->
              cond do
                not released?(members, entries || %{}) -> :pending
                thread in reviewed -> :reviewed
                true -> :unreviewed
              end
            end)
        end)

      counts = Enum.frequencies(states)
      pending = Map.get(counts, :pending, 0)
      unreviewed = Map.get(counts, :unreviewed, 0)

      %{
        reviewed: Map.get(counts, :reviewed, 0),
        unreviewed: unreviewed,
        pending: pending,
        caught_up?: unreviewed == 0,
        delivery_pending?: pending > 0
      }
    end)
  end

  defp released?(members, entries),
    do: Enum.all?(members, &(get_in(entries, [&1, "state"]) == "released"))

  defp ledger(snapshot_id) do
    Repo.query!(
      "SELECT groups, reviewed FROM phase_zero_batch_reviews WHERE snapshot_id = $1::text::uuid",
      [snapshot_id]
    ).rows
    |> List.first()
  end

  defp journal(snapshot_id) do
    case Repo.query!(
           "SELECT entries FROM phase_zero_release_journals WHERE snapshot_id = $1::text::uuid",
           [snapshot_id]
         ).rows do
      [[entries]] -> entries
      [] -> %{}
    end
  end

  defp with_snapshot(snapshot_id, fun) do
    Repo.transaction(fn ->
      case Repo.query!(
             "SELECT account_key::text FROM phase_zero_snapshots WHERE id = $1::text::uuid",
             [snapshot_id]
           ).rows do
        [[account_key]] ->
          Recovery.lock!(account_key)

          case Repo.query!(
                 "SELECT message_ids FROM phase_zero_snapshots WHERE id = $1::text::uuid FOR UPDATE",
                 [snapshot_id]
               ).rows do
            [[ids]] -> fun.(ids)
            [] -> Repo.rollback(:snapshot_not_found)
          end

        [] ->
          Repo.rollback(:snapshot_not_found)
      end
    end)
  end
end
