defmodule EmailSucks.Repo.Migrations.AddPhaseZeroRecoveries do
  use Ecto.Migration

  def change do
    create table(:phase_zero_recoveries, primary_key: false) do
      add :account_key, :uuid, primary_key: true
      add :stage, :text, null: false, default: "stopping"
    end

    create constraint(:phase_zero_recoveries, :recovery_stage,
             check: "stage IN ('stopping', 'interception_disabled')"
           )
  end
end
