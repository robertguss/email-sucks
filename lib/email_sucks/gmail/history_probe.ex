defmodule EmailSucks.Gmail.HistoryProbe do
  @moduledoc "Read-only recovery journal with frozen membership and atomic checkpoints."
  use Ecto.Schema
  alias EmailSucks.Repo
  alias EmailSucks.Gmail.{Batch, Controlled, HistoryProvider}
  @primary_key {:id, :string, autogenerate: false}
  @derive {Inspect, only: [:id, :revision, :checked_at, :mode, :error]}
  schema "gmail_history_probes" do
    field :message_ids, {:array, :string}, redact: true
    field :cursor, :string, redact: true
    field :observations, :map, default: %{}, redact: true
    field :revision, :integer, default: 0
    field :checked_at, :integer
    field :mode, :string
    field :error, :string
  end

  def summary do
    case Repo.get(__MODULE__, "primary", log: false) do
      nil ->
        %{
          state: "not_started",
          members: 0,
          available: 0,
          unavailable: 0,
          revision: 0,
          checked_at: nil,
          mode: nil,
          error: nil
        }

      row ->
        summary(row)
    end
  end

  defp summary(row) do
    values = Map.values(row.observations)

    %{
      state: if(row.checked_at, do: "ready", else: "pending"),
      members: length(row.message_ids),
      available: Enum.count(values, &(&1["available"] == true)),
      unavailable: Enum.count(values, &(&1["available"] == false)),
      revision: row.revision,
      checked_at: row.checked_at,
      mode: row.mode,
      error: row.error
    }
  end

  def run(config, token, action) when action in ["sync", "rescan"] do
    Controlled.exclusive(fn ->
      with {:ok, row} <- membership() do
        result =
          if action == "rescan" or is_nil(row.cursor),
            do:
              full(
                config,
                token,
                row.message_ids,
                if(action == "rescan", do: "rescan", else: "full")
              ),
            else: incremental(config, token, row)

        result =
          case result do
            {:error, :history_expired} -> full(config, token, row.message_ids, "expired_rescan")
            result -> result
          end

        case result do
          {:ok, observations, cursor, mode} ->
            row =
              save(row,
                observations: observations,
                cursor: cursor,
                mode: mode,
                error: nil,
                checked_at: System.system_time(:second),
                revision: row.revision + 1
              )

            {:ok, summary(row)}

          {:error, reason} ->
            save(row, error: Atom.to_string(reason))
            {:error, reason}
        end
      end
    end)
  end

  def run(_, _, _), do: {:error, :invalid_transition}

  defp membership do
    case Repo.get(__MODULE__, "primary", log: false) do
      nil ->
        with %{message_id: single} <- Repo.get(Controlled, "primary", log: false),
             %{entries: entries} when is_map(entries) and map_size(entries) == 3 <-
               Repo.get(Batch, "primary", log: false),
             ids = Enum.sort([single | Map.keys(entries)]),
             true <- valid_members?(ids) do
          {:ok, Repo.insert!(%__MODULE__{id: "primary", message_ids: ids}, log: false)}
        else
          _ -> {:error, :fixture_mismatch}
        end

      row ->
        if valid_members?(row.message_ids), do: {:ok, row}, else: {:error, :fixture_mismatch}
    end
  end

  defp valid_members?(ids),
    do:
      is_list(ids) and length(ids) == 4 and length(Enum.uniq(ids)) == 4 and
        Enum.all?(ids, &HistoryProvider.valid_id?/1)

  defp full(config, token, ids, mode) do
    with {:ok, start} <- HistoryProvider.profile(config, token),
         {:ok, observations} <- read(config, token, ids, %{}),
         {:ok, changed, cursor} <- HistoryProvider.changes(config, token, start, ids),
         {:ok, observations} <- read(config, token, changed, observations) do
      {:ok, observations, cursor, mode}
    end
  end

  defp incremental(config, token, row) do
    with {:ok, changed, cursor} <-
           HistoryProvider.changes(config, token, row.cursor, row.message_ids),
         {:ok, observations} <- read(config, token, changed, row.observations) do
      {:ok, observations, cursor, "incremental"}
    end
  end

  defp read(config, token, ids, observations) do
    Enum.reduce_while(ids, {:ok, observations}, fn id, {:ok, observations} ->
      case HistoryProvider.message(config, token, id) do
        {:ok, observation} -> {:cont, {:ok, Map.put(observations, id, observation)}}
        error -> {:halt, error}
      end
    end)
  end

  defp save(row, fields), do: row |> Ecto.Changeset.change(fields) |> Repo.update!(log: false)
end
