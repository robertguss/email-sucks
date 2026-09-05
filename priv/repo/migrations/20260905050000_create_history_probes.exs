defmodule EmailSucks.Repo.Migrations.CreateHistoryProbes do
  use Ecto.Migration

  def change do
    create table(:gmail_history_probes, primary_key: false) do
      add :id, :text, primary_key: true
      add :message_ids, {:array, :text}, null: false
      add :cursor, :text
      add :observations, :map, null: false, default: %{}
      add :revision, :integer, null: false, default: 0
      add :checked_at, :bigint
      add :mode, :text
      add :error, :text
    end
  end
end
