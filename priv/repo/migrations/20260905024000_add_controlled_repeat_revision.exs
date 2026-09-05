defmodule EmailSucks.Repo.Migrations.AddControlledRepeatRevision do
  use Ecto.Migration

  def change do
    alter table(:gmail_controlled) do
      add :repeat_revision, :bigint, default: 0, null: false
    end
  end
end
