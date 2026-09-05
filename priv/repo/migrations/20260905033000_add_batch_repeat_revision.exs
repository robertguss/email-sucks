defmodule EmailSucks.Repo.Migrations.AddBatchRepeatRevision do
  use Ecto.Migration

  def change do
    alter table(:gmail_batches) do
      add :repeat_revision, :integer, null: false, default: 0
    end
  end
end
