defmodule EmailSucks.Gmail.Controlled do
  @moduledoc "One controlled message experiment. Intent commits before any message mutation."
  use Ecto.Schema
  alias EmailSucks.{Repo, Gmail.Google}
  @primary_key {:id, :string, autogenerate: false}
  @derive {Inspect, only: [:id, :state]}
  schema "gmail_controlled" do
    field :message_id, :string, redact: true
    field :label_id, :string
    field :state, :string
    field :verified_at, :integer
    field :repeat_revision, :integer, default: 0
  end

  def summary do
    case Repo.get(__MODULE__, "primary", log: false) do
      nil -> %{state: "not_started", verified_at: nil}
      row -> Map.take(row, [:state, :verified_at, :repeat_revision])
    end
  end

  def run(config, token, action) when action in ["hold", "release", "recover"] do
    exclusive(fn ->
      with {:ok, row} <-
             intent(Repo.get(__MODULE__, "primary", log: false), action, config, token),
           {:ok, row} <- reconcile(row, config, token) do
        {:ok, Map.take(row, [:state, :verified_at, :repeat_revision])}
      end
    end)
  end

  def run(_, _, _), do: {:error, :invalid_transition}

  def repeat(config, token, expected_revision) do
    exclusive(fn ->
      with %{state: "released"} = row <- Repo.get(__MODULE__, "primary", log: false),
           true <-
             is_binary(expected_revision) and
               expected_revision == Integer.to_string(row.repeat_revision),
           {:ok, row} <- reconcile(row, config, token) do
        row
        |> save(state: "hold_pending", verified_at: nil, repeat_revision: row.repeat_revision + 1)
        |> reconcile(config, token)
        |> case do
          {:ok, row} -> {:ok, Map.take(row, [:state, :verified_at, :repeat_revision])}
          error -> error
        end
      else
        {:error, _} = error -> error
        _ -> {:error, :invalid_transition}
      end
    end)
  end

  def restore_for_disconnect(config, token) do
    case Repo.get(__MODULE__, "primary", log: false) do
      nil ->
        :ok

      _ ->
        case run(config, token, "release") do
          {:ok, %{state: "released"}} -> :ok
          error -> error
        end
    end
  end

  @doc false
  def exclusive(operation) do
    # One connection-scoped lock covers committed intent, remote calls and token changes.
    # A crashed checkout disconnects; PostgreSQL releases the lock with the connection.
    Repo.checkout(
      fn ->
        case Repo.query!("SELECT pg_try_advisory_lock(71403)", [], log: false).rows do
          [[true]] ->
            try do
              operation.()
            after
              Repo.query!("SELECT pg_advisory_unlock(71403)", [], log: false)
            end

          _ ->
            {:error, :operation_in_progress}
        end
      end,
      timeout: 120_000
    )
  end

  defp intent(nil, "hold", config, token) do
    with {:ok, message} <- Google.controlled_fixture(config, token),
         {:ok, label} <- Google.controlled_label(config, token),
         false <- label in message["labelIds"] do
      {:ok,
       Repo.insert!(
         %__MODULE__{
           id: "primary",
           message_id: message["id"],
           label_id: label,
           state: "hold_pending"
         },
         log: false
       )}
    else
      true -> {:error, :fixture_mismatch}
      error -> error
    end
  end

  defp intent(nil, _, _, _), do: {:error, :invalid_transition}

  defp intent(%{state: state} = row, "release", _, _) when state in ["hold_pending", "held"] do
    {:ok, save(row, state: "release_pending", verified_at: nil)}
  end

  defp intent(%{state: "released"}, "hold", _, _), do: {:error, :invalid_transition}
  defp intent(%{state: "release_pending"}, "hold", _, _), do: {:error, :invalid_transition}
  defp intent(row, _, _, _), do: {:ok, row}

  defp reconcile(row, config, token) do
    with :ok <-
           EmailSucks.Gmail.Projection.reconcile(
             config,
             token,
             row.message_id,
             row.label_id,
             row.state in ["hold_pending", "held"],
             row.state in ["hold_pending", "release_pending"]
           ) do
      {:ok, verified(row)}
    end
  end

  defp verified(row) do
    state = if row.state in ["hold_pending", "held"], do: "held", else: "released"
    save(row, state: state, verified_at: System.system_time(:second))
  end

  defp save(row, fields), do: row |> Ecto.Changeset.change(fields) |> Repo.update!(log: false)
end
