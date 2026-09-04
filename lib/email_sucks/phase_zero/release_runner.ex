defmodule EmailSucks.PhaseZero.ReleaseRunner do
  @moduledoc """
  One synthetic release step with a fixture provider callback, never a Gmail client.
  Inspect returns held/released/unavailable; release returns :ok or an error.
  Unknown results leave the durable claim unresolved. No automatic retry loop.
  """
  alias EmailSucks.PhaseZero.ReleaseJournal

  def step(snapshot_id, provider, now \\ System.system_time(:second))
      when is_function(provider, 2) do
    case ReleaseJournal.claim(snapshot_id, now) do
      {:ok, %{message_id: id, token: token, action: action}} ->
        outcome =
          case provider.(:inspect, id) do
            :held when action == :apply ->
              case provider.(:release, id) do
                :ok -> observe(provider.(:inspect, id))
                _ -> :unknown
              end

            state ->
              observe(state)
          end

        if outcome == :unknown do
          {:error, :provider_unavailable}
        else
          case ReleaseJournal.record(snapshot_id, id, token, outcome) do
            {:ok, :recorded} -> {:ok, %{message_id: id, outcome: outcome}}
            error -> error
          end
        end

      result ->
        result
    end
  end

  defp observe(:held), do: :pending
  defp observe(:released), do: :released
  defp observe(:unavailable), do: :unavailable
  defp observe(_), do: :unknown
end
