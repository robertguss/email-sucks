defmodule EmailSucks.Repo.Migrations.AddPhaseZeroReleaseJournals do
  use Ecto.Migration

  def change do
    create table(:phase_zero_release_journals, primary_key: false) do
      add :snapshot_id, references(:phase_zero_snapshots, type: :uuid, on_delete: :delete_all),
        primary_key: true

      add :entries, :map, null: false
    end
  end
end
