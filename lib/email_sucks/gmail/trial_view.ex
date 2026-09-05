defmodule EmailSucks.Gmail.TrialView do
  @moduledoc "Ephemeral previews and durable per-delivery review state."
  alias EmailSucks.Repo
  alias EmailSucks.Gmail.{BatchViewProvider, Controlled, Trial, TrialRun}

  def load(config, token) do
    Controlled.exclusive(fn ->
      case Trial.latest() do
        nil ->
          {:ok,
           %{
             revision: nil,
             run_id: nil,
             state: "empty",
             items: [],
             total: 0,
             remaining: 0,
             pending: 0,
             unavailable: 0
           }}

        run ->
          load_run(config, token, run)
      end
    end)
  end

  def review(config, token, run_id, revision, item_id, reviewed)
      when is_integer(revision) and is_binary(item_id) and is_boolean(reviewed) do
    Controlled.exclusive(fn ->
      with {:ok, id} <- Ecto.UUID.cast(run_id),
           %TrialRun{revision: ^revision} = run <- Repo.get(TrialRun, id, log: false),
           true <- is_map(run.groups) and Map.has_key?(run.groups, item_id),
           {:ok, messages} <- read_messages(config, token, Map.keys(run.entries)),
           view = present(run, messages),
           %{status: "available"} <- Enum.find(view.items, &(&1.id == item_id)) do
        ids =
          if reviewed,
            do: Enum.uniq([item_id | run.reviewed]),
            else: List.delete(run.reviewed, item_id)

        run = run |> Ecto.Changeset.change(reviewed: ids) |> Repo.update!(log: false)
        {:ok, present(run, messages)}
      else
        {:error, _} = error -> error
        _ -> {:error, :stale}
      end
    end)
  end

  def review(_, _, _, _, _, _), do: {:error, :stale}

  defp load_run(config, token, run) do
    with {:ok, messages} <- read_messages(config, token, Map.keys(run.entries)) do
      run =
        if is_nil(run.groups) do
          # Freeze groups once; missing messages retain their own visible exception row.
          groups =
            Enum.group_by(Map.keys(run.entries), fn id ->
              if messages[id], do: messages[id].thread, else: id
            end)

          run |> Ecto.Changeset.change(groups: groups) |> Repo.update!(log: false)
        else
          run
        end

      {:ok, present(run, messages)}
    end
  end

  defp read_messages(config, token, ids) do
    Enum.reduce_while(ids, {:ok, %{}}, fn id, {:ok, messages} ->
      case BatchViewProvider.message(config, token, id) do
        {:ok, message} -> {:cont, {:ok, Map.put(messages, id, message)}}
        error -> {:halt, error}
      end
    end)
  end

  defp present(run, messages) do
    groups = run.groups

    items =
      groups
      |> Enum.sort()
      |> Enum.map(fn {group, ids} ->
        contents =
          Enum.map(Enum.sort(ids), fn id ->
            message = messages[id]
            entry = run.entries[id]

            status =
              cond do
                entry["state"] in ["excluded", "gone"] or is_nil(message) or
                    Enum.any?(message.labels, &(&1 in ["TRASH", "SPAM", "DRAFT"])) ->
                  "unavailable"

                (entry["state"] != "released" and run.state != "cancelled") or
                  entry["error"] != nil or
                    run.label_id in message.labels ->
                  "pending"

                message.thread != group ->
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
            "pending" in states -> "pending"
            true -> "available"
          end

        %{
          id: group,
          contents: contents,
          messages: length(ids),
          reviewed: group in run.reviewed,
          status: status
        }
      end)

    pending = Enum.count(items, &(&1.status == "pending"))
    unavailable = Enum.count(items, &(&1.status == "unavailable"))

    %{
      revision: run.revision,
      run_id: run.id,
      state: if(pending + unavailable > 0, do: "pending", else: "ready"),
      items: items,
      total: length(items),
      remaining: Enum.count(items, &(!&1.reviewed and &1.status == "available")),
      pending: pending,
      unavailable: unavailable
    }
  end
end
