defmodule EmailSucks.Repo.Migrations.AddGmailDisconnect do
  use Ecto.Migration

  def change do
    alter table(:gmail_accounts) do
      add :disconnect_phase, :text
    end

    create constraint(:gmail_accounts, :valid_disconnect_phase,
             check: "disconnect_phase IS NULL OR disconnect_phase IN ('restoring', 'revoking')"
           )
  end
end
