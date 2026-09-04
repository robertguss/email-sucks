defmodule EmailSucks.Repo.Migrations.AddPhaseZeroScheduling do
  use Ecto.Migration

  def change do
    create table(:phase_zero_schedules, primary_key: false) do
      add :account_key, :uuid, primary_key: true
      add :revision, :bigint, null: false
    end

    create table(:phase_zero_delivery_runs, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :account_key, :uuid, null: false
      add :request_key, :text, null: false
      add :snapshot_id, references(:phase_zero_snapshots, type: :uuid), null: false
      add :status, :text, null: false, default: "active"
    end

    create unique_index(:phase_zero_delivery_runs, [:account_key], where: "status = 'active'")
    create unique_index(:phase_zero_delivery_runs, [:account_key, :request_key])

    create table(:phase_zero_occurrences, primary_key: false) do
      add :id, :text, primary_key: true
      add :account_key, :uuid, null: false
      add :revision, :bigint, null: false
      add :scheduled_unix, :bigint, null: false
      add :resolution, :map, null: false
      add :status, :text, null: false, default: "planned"
      add :run_id, references(:phase_zero_delivery_runs, type: :uuid)
    end

    create index(:phase_zero_occurrences, [:account_key, :scheduled_unix],
             where: "status = 'planned'"
           )

    create constraint(:phase_zero_delivery_runs, :run_status,
             check: "status IN ('active', 'completed')"
           )

    create constraint(:phase_zero_occurrences, :occurrence_status,
             check: "status IN ('planned', 'claimed', 'cancelled')"
           )
  end
end
