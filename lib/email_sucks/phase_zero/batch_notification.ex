defmodule EmailSucks.PhaseZero.BatchNotification do
  @moduledoc """
  Synthetic notification receipt. The injected fixture callback is not a real
  transport. Only an explicit confirmed non-delivery (:rejected) permits retry;
  timeout, exception or unrecognized result remains unknown.
  """
  alias EmailSucks.Repo
  alias EmailSucks.PhaseZero.{Recovery, ReleaseJournal}

  def deliver(_snapshot_id, false, _provider), do: {:ok, :disabled}

  def deliver(snapshot_id, true, provider) when is_function(provider, 1) do
    case claim(snapshot_id) do
      {:ok, %{conversation_count: count}} ->
        state =
          case provider.(%{batch_id: snapshot_id, conversation_count: count}) do
            :ok -> :sent
            :rejected -> :rejected
            _ -> :unknown
          end

        Repo.query!(
          "UPDATE phase_zero_batch_notifications SET state = $2 WHERE snapshot_id = $1::text::uuid AND state = 'unknown'",
          [snapshot_id, Atom.to_string(state)]
        )

        {:ok, state}

      result ->
        result
    end
  end

  defp claim(snapshot_id) do
    Repo.transaction(fn ->
      account =
        case Repo.query!(
               "SELECT account_key::text FROM phase_zero_snapshots WHERE id = $1::text::uuid",
               [snapshot_id]
             ).rows do
          [[account]] -> account
          [] -> Repo.rollback(:snapshot_not_found)
        end

      Recovery.lock!(account)
      Recovery.ensure_normal!(account)
      {:ok, status} = ReleaseJournal.status(snapshot_id)
      unless status.complete?, do: Repo.rollback(:release_incomplete)

      if status.released == 0 do
        :empty
      else
        count =
          case Repo.query!(
                 "SELECT groups FROM phase_zero_batch_reviews WHERE snapshot_id = $1::text::uuid",
                 [snapshot_id]
               ).rows do
            [[groups]] -> map_size(groups)
            [] -> Repo.rollback(:unprepared_batch)
          end

        case Repo.query!(
               "SELECT state FROM phase_zero_batch_notifications WHERE snapshot_id = $1::text::uuid",
               [snapshot_id]
             ).rows do
          [["sent"]] ->
            :sent

          [["unknown"]] ->
            :unknown

          _ ->
            Repo.query!(
              "INSERT INTO phase_zero_batch_notifications (snapshot_id, state) VALUES ($1::text::uuid, 'unknown') ON CONFLICT (snapshot_id) DO UPDATE SET state = 'unknown'",
              [snapshot_id]
            )

            %{conversation_count: count}
        end
      end
    end)
  end
end
