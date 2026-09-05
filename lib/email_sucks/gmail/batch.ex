defmodule EmailSucks.Gmail.Batch do
  @moduledoc "One fixed three-fixture batch. Each result commits before advancing to the next member."
  use Ecto.Schema
  alias EmailSucks.Repo
  alias EmailSucks.Gmail.{Controlled, Google, Projection}
  @primary_key {:id, :string, autogenerate: false}
  @derive {Inspect, only: [:id, :state]}
  schema "gmail_batches" do
    field :state, :string
    field :label_id, :string
    field :entries, :map, redact: true
  end

  def summary do
    case Repo.get(__MODULE__, "primary", log: false) do
      nil -> %{state: "not_started", total: 0, held: 0, released: 0, pending: 0, errors: 0}
      row -> summary(row)
    end
  end

  defp summary(row) do
    values = Map.values(row.entries)

    %{
      state: row.state,
      total: length(values),
      held: Enum.count(values, &(&1["state"] == "held")),
      released: Enum.count(values, &(&1["state"] == "released")),
      pending: Enum.count(values, &(&1["state"] in ["hold_pending", "release_pending"])),
      errors: Enum.count(values, &(not is_nil(&1["error"])))
    }
  end

  def run(config, token, action) when action in ["hold", "release", "recover"] do
    Controlled.exclusive(fn ->
      with {:ok, row} <-
             intent(Repo.get(__MODULE__, "primary", log: false), config, token, action) do
        {row, error} =
          row.entries
          |> Map.keys()
          |> Enum.sort()
          |> Enum.reduce({row, nil}, fn id, {row, error} ->
            entry = row.entries[id]

            result =
              Projection.reconcile(
                config,
                token,
                id,
                row.label_id,
                entry["state"] in ["hold_pending", "held"],
                entry["state"] in ["hold_pending", "release_pending"]
              )

            {entry, error} =
              case result do
                :ok ->
                  {%{
                     "state" =>
                       if(entry["state"] in ["hold_pending", "held"],
                         do: "held",
                         else: "released"
                       ),
                     "error" => nil
                   }, error}

                {:error, reason} ->
                  {Map.put(entry, "error", Atom.to_string(reason)), error || reason}
              end

            {save(row, entries: Map.put(row.entries, id, entry)), error}
          end)

        counts = summary(row)

        state =
          cond do
            error -> if row.state in ["holding", "held"], do: "holding", else: "releasing"
            counts.released == counts.total -> "released"
            counts.held == counts.total -> "held"
            true -> row.state
          end

        row = save(row, state: state)
        if error, do: {:error, error}, else: {:ok, summary(row)}
      end
    end)
  end

  def run(_, _, _), do: {:error, :invalid_transition}

  def restore_for_disconnect(config, token) do
    if Repo.get(__MODULE__, "primary", log: false) do
      case run(config, token, "release") do
        {:ok, %{state: "released"}} -> :ok
        error -> error
      end
    else
      :ok
    end
  end

  defp intent(nil, config, token, "hold") do
    with {:ok, messages} <- Google.batch_fixtures(config, token),
         {:ok, label} <- Google.batch_label(config, token),
         false <- Enum.any?(messages, &(label in &1["labelIds"])) do
      entries = Map.new(messages, &{&1["id"], %{"state" => "hold_pending", "error" => nil}})

      {:ok,
       Repo.insert!(
         %__MODULE__{id: "primary", state: "holding", label_id: label, entries: entries},
         log: false
       )}
    else
      true -> {:error, :fixture_mismatch}
      error -> error
    end
  end

  defp intent(nil, _, _, _), do: {:error, :invalid_transition}
  defp intent(_, _, _, "hold"), do: {:error, :invalid_transition}

  defp intent(row, _, _, "release") do
    entries =
      Map.new(row.entries, fn {id, entry} ->
        {id,
         if(entry["state"] == "released",
           do: entry,
           else: %{"state" => "release_pending", "error" => nil}
         )}
      end)

    {:ok, save(row, state: "releasing", entries: entries)}
  end

  defp intent(row, _, _, "recover"), do: {:ok, row}
  defp save(row, fields), do: row |> Ecto.Changeset.change(fields) |> Repo.update!(log: false)
end
