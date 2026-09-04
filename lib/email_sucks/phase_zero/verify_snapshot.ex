defmodule EmailSucks.PhaseZero.VerifySnapshot do
  @moduledoc "Proves Oban can read a committed snapshot; never releases or sends mail."
  use Oban.Worker, queue: :phase_zero

  alias EmailSucks.PhaseZero.Snapshot

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"snapshot_id" => id}}) do
    Snapshot
    |> Ash.get!(id, authorize?: false)
    |> Ash.Changeset.for_update(:verify)
    |> Ash.update!(authorize?: false)

    :ok
  end
end
