defmodule EmailSucks.Repo.Migrations.AddPhaseZeroManualReceipts do
  use Ecto.Migration

  def change do
    create table(:phase_zero_manual_receipts, primary_key: false) do
      add :account_key, :uuid, primary_key: true
      add :request_id, :text, primary_key: true
      add :run_id, references(:phase_zero_delivery_runs, type: :uuid), null: false
    end
  end
end
