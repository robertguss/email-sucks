defmodule EmailSucks.PhaseZero do
  @moduledoc """
  Internal, synthetic probes for the persistence/job boundary. No Gmail I/O.
  Account keys identify test fixtures, not authenticated Gmail accounts.
  """
  use Ash.Domain, otp_app: :email_sucks
  require Ash.Query

  alias EmailSucks.Repo
  alias EmailSucks.PhaseZero.{Snapshot, VerifySnapshot}

  resources do
    resource Snapshot
  end

  @doc "Freezes supplied IDs and enqueues their verification in one transaction."
  def freeze(account_key, message_ids) when is_list(message_ids) do
    if Enum.all?(message_ids, &(is_binary(&1) and String.trim(&1) != "")) do
      Repo.transaction(fn ->
        # PostgreSQL owns serialization, including across BEAM instances.
        # Hash collisions only serialize unrelated fixtures; they cannot mix data.
        Ecto.Adapters.SQL.query!(Repo, "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))", [
          account_key
        ])

        case Snapshot
             |> Ash.Query.filter(account_key == ^account_key and status == :pending)
             |> Ash.read_one!(authorize?: false) do
          nil -> create_snapshot(account_key, message_ids)
          snapshot -> snapshot
        end
      end)
    else
      {:error, :invalid_membership}
    end
  end

  defp create_snapshot(account_key, message_ids) do
    # This internal probe has no notification consumers. The Oban row is its durable work signal.
    {snapshot, _notifications} =
      Snapshot
      |> Ash.Changeset.for_create(:freeze, %{
        account_key: account_key,
        message_ids: Enum.sort(Enum.uniq(message_ids))
      })
      |> Ash.create!(authorize?: false, return_notifications?: true)

    %{snapshot_id: snapshot.id}
    |> VerifySnapshot.new()
    |> Oban.insert!()

    snapshot
  end
end
