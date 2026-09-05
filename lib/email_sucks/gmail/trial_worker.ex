defmodule EmailSucks.Gmail.TrialWorker do
  @moduledoc "Web-only delivery execution; jobs carry an intent UUID, never credentials."
  use Oban.Worker, queue: :gmail_delivery, max_attempts: 20
  @impl Oban.Worker
  def timeout(_job), do: :timer.seconds(55)
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"run_id" => id} = args}) when map_size(args) == 1 do
    case EmailSucks.Gmail.execute_trial(id) do
      {:ok, _} -> :ok
      {:error, :invalid_transition} -> {:cancel, :stopped}
      {:error, reason} -> {:error, reason}
    end
  end

  def perform(_), do: {:cancel, :invalid_intent}
end
