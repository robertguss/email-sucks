defmodule EmailSucks.Repo.Migrations.AddPhaseZeroBatchNotifications do
  use Ecto.Migration

  def change do
    create table(:phase_zero_batch_notifications, primary_key: false) do
      add :snapshot_id, references(:phase_zero_snapshots, type: :uuid, on_delete: :delete_all),
        primary_key: true

      add :state, :text, null: false
    end

    create constraint(:phase_zero_batch_notifications, :notification_state,
             check: "state IN ('unknown', 'sent', 'rejected')"
           )
  end
end
