defmodule EmailSucks.Repo.Migrations.AddPhaseZeroBatchReviews do
  use Ecto.Migration

  def change do
    create table(:phase_zero_batch_reviews, primary_key: false) do
      add :snapshot_id, references(:phase_zero_snapshots, type: :uuid, on_delete: :delete_all),
        primary_key: true

      add :groups, :map, null: false
      add :reviewed, {:array, :text}, null: false, default: []
    end
  end
end
