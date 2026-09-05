defmodule EmailSucks.Repo.Migrations.CreateDeliveryTrial do
  use Ecto.Migration

  def change do
    create table(:gmail_trials, primary_key: false) do
      add :id, :string, primary_key: true
      add :state, :string, null: false
      add :next_due, :bigint
      add :error, :string
    end

    create constraint(:gmail_trials, :trial_singleton,
             check: "id = 'primary' AND state IN ('starting','active','stopping','stopped')"
           )

    create table(:gmail_trial_runs, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :kind, :string, null: false
      add :due_at, :bigint, null: false
      add :state, :string, null: false
      add :label_id, :string
      add :entries, :map, null: false, default: %{}
      add :groups, :map
      add :reviewed, {:array, :string}, null: false, default: []
      add :revision, :integer, null: false, default: 1
      add :error, :string
      add :completed_at, :bigint
    end

    create constraint(:gmail_trial_runs, :run_states,
             check:
               "kind IN ('manual','scheduled') AND state IN ('planned','frozen','complete','cancelled')"
           )

    create unique_index(:gmail_trial_runs, [:due_at],
             where: "kind = 'scheduled'",
             name: :trial_scheduled_due_unique
           )

    create table(:gmail_trial_requests, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :run_id, references(:gmail_trial_runs, type: :uuid), null: false
    end
  end
end
