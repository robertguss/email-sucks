defmodule EmailSucks.Repo.Migrations.RecordFilterBaselineWarning do
  use Ecto.Migration

  def change do
    alter table(:gmail_filter_experiments) do
      add :baseline_changed, :boolean, default: false, null: false
    end
  end
end
