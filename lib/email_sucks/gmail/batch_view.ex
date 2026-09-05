defmodule EmailSucks.Gmail.BatchView do
  @moduledoc "App-only review ledger for the exact saved three-message batch."
  use Ecto.Schema
  alias EmailSucks.Repo
  alias EmailSucks.Gmail.{Batch, BatchViewProvider, Controlled, HistoryProvider}
  @primary_key {:id, :string, autogenerate: false}
  @derive {Inspect, only: [:id, :revision]}
  schema "gmail_batch_views" do
    field :revision, :integer
    field :source_revision, :integer
    field :message_ids, {:array, :string}, redact: true
    field :groups, :map, redact: true
    field :reviewed, {:array, :string}, default: [], redact: true
  end

  def load(config, token), do: Controlled.exclusive(fn -> load_locked(config, token) end)

  def review(config, token, revision, item_id, reviewed)
      when is_integer(revision) and is_binary(item_id) and is_boolean(reviewed) do
    Controlled.exclusive(fn ->
      source = Repo.get(Batch, "primary", log: false)
      ledger = Repo.get(__MODULE__, "primary", log: false)

      with true <- current?(ledger, source) and ledger.revision == revision,
           true <- Map.has_key?(ledger.groups, item_id),
           {:ok, messages} <- read_messages(config, token, ledger.message_ids),
           view = present(source, ledger, messages),
           %{status: "available"} <- Enum.find(view.items, &(&1.id == item_id)) do
        ids =
          if reviewed,
            do: Enum.uniq([item_id | ledger.reviewed]),
            else: List.delete(ledger.reviewed, item_id)

        updated = ledger |> Ecto.Changeset.change(reviewed: ids) |> Repo.update!(log: false)
        {:ok, present(source, updated, messages)}
      else
        {:error, _} = error -> error
        _ -> {:error, :stale}
      end
    end)
  end

  def review(_, _, _, _, _), do: {:error, :stale}

  defp load_locked(config, token) do
    case Repo.get(Batch, "primary", log: false) do
      nil ->
        {:ok,
         %{
           revision: nil,
           state: "empty",
           items: [],
           total: 0,
           remaining: 0,
           pending: 0,
           unavailable: 0
         }}

      source ->
        ids = Enum.sort(Map.keys(source.entries))

        if length(ids) == 3 and Enum.all?(ids, &HistoryProvider.valid_id?/1) do
          with {:ok, messages} <- read_messages(config, token, ids) do
            previous = Repo.get(__MODULE__, "primary", log: false)

            ledger =
              cond do
                current?(previous, source) ->
                  previous

                Enum.all?(messages, fn {_, message} -> message != nil end) ->
                  fields = [
                    revision: if(previous, do: previous.revision + 1, else: 1),
                    source_revision: source.repeat_revision,
                    message_ids: ids,
                    groups: Enum.group_by(ids, &messages[&1].thread),
                    reviewed: []
                  ]

                  (previous || %__MODULE__{id: "primary"})
                  |> Ecto.Changeset.change(fields)
                  |> Repo.insert_or_update!(log: false)

                true ->
                  nil
              end

            {:ok, present(source, ledger, messages)}
          end
        else
          {:error, :fixture_mismatch}
        end
    end
  end

  defp current?(nil, _), do: false
  defp current?(_, nil), do: false

  defp current?(ledger, source),
    do:
      ledger.source_revision == source.repeat_revision and
        ledger.message_ids == Enum.sort(Map.keys(source.entries))

  defp read_messages(config, token, ids) do
    Enum.reduce_while(ids, {:ok, %{}}, fn id, {:ok, messages} ->
      case BatchViewProvider.message(config, token, id) do
        {:ok, message} -> {:cont, {:ok, Map.put(messages, id, message)}}
        error -> {:halt, error}
      end
    end)
  end

  defp present(source, ledger, messages) do
    groups = if ledger, do: ledger.groups, else: Map.new(messages, fn {id, _} -> {id, [id]} end)

    items =
      groups
      |> Enum.sort()
      |> Enum.map(fn {group, ids} ->
        contents =
          Enum.map(Enum.sort(ids), fn id ->
            message = messages[id]
            entry = source.entries[id]

            status =
              cond do
                is_nil(message) or Enum.any?(message.labels, &(&1 in ["TRASH", "SPAM", "DRAFT"])) ->
                  "unavailable"

                entry["state"] != "released" or entry["error"] != nil or
                    source.label_id in message.labels ->
                  "pending"

                ledger && message.thread != group ->
                  "unavailable"

                true ->
                  "available"
              end

            %{
              id: id,
              subject: if(message, do: message.subject, else: "Message unavailable"),
              sender: if(message, do: message.sender, else: ""),
              preview: if(message, do: message.preview, else: ""),
              received_at: message && message.received_at,
              status: status
            }
          end)

        states = Enum.map(contents, & &1.status)

        status =
          cond do
            "unavailable" in states -> "unavailable"
            "pending" in states or is_nil(ledger) -> "pending"
            true -> "available"
          end

        %{
          id: group,
          contents: contents,
          messages: length(ids),
          reviewed: ledger != nil and group in ledger.reviewed,
          status: status
        }
      end)

    pending = Enum.count(items, &(&1.status == "pending"))
    unavailable = Enum.count(items, &(&1.status == "unavailable"))

    %{
      revision: ledger && ledger.revision,
      state: if(pending + unavailable > 0, do: "pending", else: "ready"),
      items: items,
      total: length(items),
      remaining: Enum.count(items, &(!&1.reviewed and &1.status == "available")),
      pending: pending,
      unavailable: unavailable
    }
  end
end
