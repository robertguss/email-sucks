defmodule EmailSucks.Repo.Migrations.CreateGmailBatches do
  use Ecto.Migration

  def change do
    create table(:gmail_batches, primary_key: false) do
      add :id, :text, primary_key: true
      add :state, :text, null: false
      add :label_id, :text, null: false
      add :entries, :map, null: false
    end
  end
end
