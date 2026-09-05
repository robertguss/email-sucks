defmodule EmailSucks.Gmail.Account do
  @moduledoc false
  use Ecto.Schema
  @derive {Inspect, only: [:id, :status]}
  @primary_key {:id, :string, autogenerate: false}
  schema "gmail_accounts" do
    field :subject, :string, redact: true
    field :email, :string, redact: true
    field :credentials, :string, redact: true
    field :disconnect_phase, :string
    field :status, :string, default: "connected"
    field :session_digest, :string, redact: true
    field :session_expires_at, :integer, default: 0
    field :checked_at, :integer
    field :revision, :integer, default: 0
    field :refresh_until, :integer, default: 0
  end
end
