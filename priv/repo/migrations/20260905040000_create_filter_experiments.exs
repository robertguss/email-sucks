defmodule EmailSucks.Repo.Migrations.CreateFilterExperiments do
  use Ecto.Migration

  def change do
    create table(:gmail_filter_experiments, primary_key: false) do
      add :id, :text, primary_key: true
      add :state, :text, null: false
      add :nonce, :text, null: false
      add :label_id, :text
      add :baseline_ids, {:array, :text}, null: false
      add :baseline_digest, :text, null: false
      add :entries, :map, null: false, default: %{}
      add :mail, :map, null: false, default: %{}
      add :observed, :integer, null: false, default: 0
      add :excluded, :integer, null: false, default: 0
      add :error, :text
    end
  end
end
