defmodule EmailSucks.Repo.Migrations.CreateBatchViews do
  use Ecto.Migration

  def change do
    create table(:gmail_batch_views, primary_key: false) do
      add :id, :text, primary_key: true
      add :revision, :integer, null: false
      add :source_revision, :integer, null: false
      add :message_ids, {:array, :text}, null: false
      add :groups, :map, null: false
      add :reviewed, {:array, :text}, null: false, default: []
    end
  end
end
