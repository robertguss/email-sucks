defmodule EmailSucks.Gmail.Flow do
  @moduledoc false
  use Ecto.Schema
  @derive {Inspect, only: [:expires_at, :consumed]}
  @primary_key {:id, :string, autogenerate: false}
  schema "gmail_oauth_flows" do
    field :payload, :string, redact: true
    field :created_at, :integer
    field :expires_at, :integer
    field :consumed, :boolean, default: false
  end
end
