defmodule EmailSucks.Repo.Migrations.AddGmailControlled do
  use Ecto.Migration

  def change do
    create table(:gmail_controlled, primary_key: false) do
      add :id, references(:gmail_accounts, type: :string, on_delete: :restrict), primary_key: true
      add :message_id, :text, null: false
      add :label_id, :text, null: false
      add :state, :text, null: false
      add :verified_at, :bigint
    end

    create constraint(:gmail_controlled, :valid_state,
             check: "state IN ('hold_pending', 'held', 'release_pending', 'released')"
           )
  end
end
