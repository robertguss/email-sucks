defmodule EmailSucks.PhaseZero.Snapshot do
  @moduledoc "A synthetic feasibility record, not a Gmail delivery batch."
  use Ash.Resource,
    otp_app: :email_sucks,
    domain: EmailSucks.PhaseZero,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "phase_zero_snapshots"
    repo EmailSucks.Repo
    identity_wheres_to_sql one_pending_per_account: "status = 'pending'"
  end

  actions do
    defaults [:read]

    create :freeze do
      accept [:account_key, :message_ids]
    end

    update :verify do
      accept []
      change set_attribute(:status, :verified)
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :account_key, :uuid, allow_nil?: false
    attribute :message_ids, {:array, :string}, allow_nil?: false

    attribute :status, :atom,
      constraints: [one_of: [:pending, :verified]],
      default: :pending,
      allow_nil?: false

    create_timestamp :inserted_at
  end

  identities do
    identity :one_pending_per_account, [:account_key], where: expr(status == :pending)
  end
end
