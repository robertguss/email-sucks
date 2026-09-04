defmodule EmailSucks.PhaseZero.Scheduling do
  @moduledoc """
  Durable synthetic scheduling probe. No timer or Gmail I/O. Callers supply fixture
  held IDs; a production sync cursor/selection boundary is still required.
  """
  alias EmailSucks.{PhaseZero, Repo}
  alias EmailSucks.PhaseZero.{Occurrence, Recovery, ReleaseJournal, Snapshot}

  def plan(account, revision, date, time, zone) when is_integer(revision) and revision > 0 do
    transaction(account, fn ->
      if time.second != 0 or elem(time.microsecond, 0) != 0,
        do: Repo.rollback(:invalid_window_time)

      Repo.query!(
        "INSERT INTO phase_zero_schedules VALUES ($1::text::uuid, $2) ON CONFLICT DO NOTHING",
        [account, revision]
      )

      unless current_revision(account) == revision, do: Repo.rollback(:stale_revision)
      key = Occurrence.identity(account, revision, date, time, zone)

      case Repo.query!("SELECT resolution FROM phase_zero_occurrences WHERE id = $1", [key]).rows do
        [[saved]] ->
          saved

        [] ->
          resolved =
            case Occurrence.resolve(account, revision, date, time, zone) do
              {:ok, value} -> value
              {:error, reason} -> Repo.rollback(reason)
            end

          saved = Jason.decode!(Jason.encode!(resolved))

          Repo.query!(
            "INSERT INTO phase_zero_occurrences (id, account_key, revision, scheduled_unix, resolution) VALUES ($1, $2::text::uuid, $3, $4, $5)",
            [key, account, revision, DateTime.to_unix(resolved.scheduled_at), saved]
          )

          saved
      end
    end)
  end

  def change_revision(account, revision) when is_integer(revision) and revision > 0 do
    transaction(account, fn ->
      current = current_revision(account)
      if current && revision < current, do: Repo.rollback(:stale_revision)

      Repo.query!(
        "INSERT INTO phase_zero_schedules VALUES ($1::text::uuid, $2) ON CONFLICT (account_key) DO UPDATE SET revision = EXCLUDED.revision",
        [account, revision]
      )

      Repo.query!(
        "UPDATE phase_zero_occurrences SET status = 'cancelled' WHERE account_key = $1::text::uuid AND status = 'planned' AND revision < $2",
        [account, revision]
      )

      :updated
    end)
  end

  def claim_due(account, now, message_ids) when is_integer(now) do
    transaction(account, fn ->
      Recovery.ensure_normal!(account)

      case active(account) do
        nil ->
          due =
            Repo.query!(
              "SELECT id FROM phase_zero_occurrences WHERE account_key = $1::text::uuid AND status = 'planned' AND scheduled_unix <= $2 ORDER BY scheduled_unix, id",
              [account, now]
            ).rows
            |> List.flatten()

          case due do
            [] ->
              :nothing_due

            [oldest | _] ->
              run = create_run(account, "scheduled:" <> oldest, message_ids)

              Repo.query!(
                "UPDATE phase_zero_occurrences SET status = 'claimed', run_id = $2::text::uuid WHERE id = ANY($1::text[])",
                [due, run.id]
              )

              get_run(account, run.id)
          end

        run ->
          run
      end
    end)
  end

  def check_now(account, request_id, message_ids)
      when is_binary(request_id) and byte_size(request_id) > 0 do
    transaction(account, fn ->
      Recovery.ensure_normal!(account)

      case Repo.query!(
             "SELECT run_id::text FROM phase_zero_manual_receipts WHERE account_key = $1::text::uuid AND request_id = $2",
             [account, request_id]
           ).rows do
        [[id]] ->
          get_run(account, id)

        [] ->
          run = active(account) || create_run(account, "manual:" <> request_id, message_ids)

          Repo.query!(
            "INSERT INTO phase_zero_manual_receipts VALUES ($1::text::uuid, $2, $3::text::uuid)",
            [account, request_id, run.id]
          )

          run
      end
    end)
  end

  def finish(account, run_id) do
    transaction(account, fn ->
      Recovery.ensure_normal!(account)
      run = get_run(account, run_id) || Repo.rollback(:run_not_found)

      if run.status != "completed" do
        {:ok, state} = ReleaseJournal.status(run.snapshot_id)
        unless state.complete?, do: Repo.rollback(:release_incomplete)

        # This synthetic resource has no external notification consumers.
        {_snapshot, _notifications} =
          Snapshot
          |> Ash.get!(run.snapshot_id, authorize?: false)
          |> Ash.Changeset.for_update(:verify)
          |> Ash.update!(authorize?: false, return_notifications?: true)

        Repo.query!(
          "UPDATE phase_zero_delivery_runs SET status = 'completed' WHERE id = $1::text::uuid",
          [run_id]
        )
      end

      :completed
    end)
  end

  defp create_run(account, key, message_ids) do
    snapshot =
      case PhaseZero.freeze(account, message_ids) do
        {:ok, snapshot} -> snapshot
        {:error, reason} -> Repo.rollback(reason)
      end

    id = Ecto.UUID.generate()

    Repo.query!(
      "INSERT INTO phase_zero_delivery_runs (id, account_key, request_key, snapshot_id) VALUES ($1::text::uuid, $2::text::uuid, $3, $4::text::uuid)",
      [id, account, key, snapshot.id]
    )

    get_run(account, id)
  end

  defp active(account) do
    case Repo.query!(
           "SELECT id::text FROM phase_zero_delivery_runs WHERE account_key = $1::text::uuid AND status = 'active'",
           [account]
         ).rows do
      [[id]] -> get_run(account, id)
      [] -> nil
    end
  end

  defp get_run(account, id) do
    case Repo.query!(
           "SELECT r.id::text, r.snapshot_id::text, r.status, (SELECT count(*) FROM phase_zero_occurrences o WHERE o.run_id = r.id) FROM phase_zero_delivery_runs r WHERE r.account_key = $1::text::uuid AND r.id = $2::text::uuid",
           [account, id]
         ).rows do
      [[id, snapshot, status, count]] ->
        %{id: id, snapshot_id: snapshot, status: status, occurrence_count: count}

      [] ->
        nil
    end
  end

  defp current_revision(account) do
    case Repo.query!(
           "SELECT revision FROM phase_zero_schedules WHERE account_key = $1::text::uuid",
           [account]
         ).rows do
      [[revision]] -> revision
      [] -> nil
    end
  end

  defp transaction(account, fun) do
    Repo.transaction(fn ->
      Recovery.lock!(account)
      fun.()
    end)
  end
end
