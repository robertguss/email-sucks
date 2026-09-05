defmodule EmailSucks.Gmail.TrialRun do
  @moduledoc "A frozen delivery and its app-only review ledger. No message contents are persisted."
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Inspect, only: [:id, :state, :kind]}
  schema "gmail_trial_runs" do
    field :kind, :string
    field :due_at, :integer
    field :state, :string, default: "planned"
    field :label_id, :string, redact: true
    field :entries, :map, default: %{}, redact: true
    field :groups, :map, redact: true
    field :reviewed, {:array, :string}, default: [], redact: true
    field :revision, :integer, default: 1
    field :error, :string
    field :completed_at, :integer
  end
end
