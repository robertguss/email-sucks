defmodule EmailSucks.Repo.Migrations.AddGmailConnection do
  use Ecto.Migration

  def change do
    create table(:gmail_oauth_flows, primary_key: false) do
      add :id, :text, primary_key: true
      add :payload, :text, null: false
      add :created_at, :bigint, null: false
      add :expires_at, :bigint, null: false
      add :consumed, :boolean, null: false, default: false
    end

    create index(:gmail_oauth_flows, [:expires_at])

    create table(:gmail_accounts, primary_key: false) do
      add :id, :text, primary_key: true
      add :subject, :text, null: false
      add :email, :text, null: false
      add :credentials, :text, null: false
      add :status, :text, null: false, default: "connected"
      add :session_digest, :text
      add :session_expires_at, :bigint, null: false, default: 0
      add :checked_at, :bigint
      add :revision, :bigint, null: false, default: 0
      add :refresh_until, :bigint, null: false, default: 0
    end

    create constraint(:gmail_accounts, :single_personal_account, check: "id = 'primary'")

    create constraint(:gmail_accounts, :valid_connection_status,
             check: "status IN ('connected', 'reconnect_required')"
           )
  end
end
