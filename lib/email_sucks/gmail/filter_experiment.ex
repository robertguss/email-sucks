defmodule EmailSucks.Gmail.FilterExperiment do
  @moduledoc "One opt-in, fixed-fixture filter proof. Intent and ownership survive every provider call."
  use Ecto.Schema
  alias EmailSucks.Repo
  alias EmailSucks.Gmail.{Controlled, FilterMail, FilterProvider, Google, Projection}
  @primary_key {:id, :string, autogenerate: false}
  @derive {Inspect, only: [:id, :state]}
  schema "gmail_filter_experiments" do
    field :state, :string
    field :nonce, :string, redact: true
    field :label_id, :string, redact: true
    field :baseline_ids, {:array, :string}, redact: true
    field :baseline_digest, :string, redact: true
    field :baseline_changed, :boolean, default: false
    field :entries, :map, default: %{}, redact: true
    field :mail, :map, default: %{}, redact: true
    field :observed, :integer, default: 0
    field :excluded, :integer, default: 0
    field :error, :string
  end

  def summary, do: summarize(Repo.get(__MODULE__, "primary", log: false))

  def run(config, token, action) when action in ~w(activate recover inspect disable) do
    Controlled.exclusive(fn ->
      row = Repo.get(__MODULE__, "primary", log: false)

      result =
        case {action, row} do
          {"activate", nil} ->
            with :ok <- FilterMail.empty?(config, token),
                 {:ok, filters} <- FilterProvider.list(config, token) do
              row =
                Repo.insert!(
                  %__MODULE__{
                    id: "primary",
                    state: "preparing",
                    nonce: Base.encode16(:crypto.strong_rand_bytes(16), case: :lower),
                    baseline_ids: Enum.map(filters, & &1["id"]),
                    baseline_digest: fingerprint(filters)
                  },
                  log: false
                )

              prepare(row, config, token)
            end

          {"activate", _} ->
            {:error, :invalid_transition}

          {_, nil} ->
            {:error, :invalid_transition}

          {"inspect", %{state: state}} when state not in ["active", "disabled"] ->
            {:error, :invalid_transition}

          {"disable", row} ->
            disable(row, config, token)

          {"recover", %{state: "preparing"} = row} ->
            prepare(row, config, token)

          {"recover", %{state: state} = row} when state in ["disabling", "disabled"] ->
            disable(row, config, token)

          {_, row} ->
            inspect_filters(row, config, token)
        end

      case result do
        {:ok, row} ->
          {:ok, summarize(save(row, error: nil))}

        {:error, :invalid_transition} = error ->
          error

        {:error, reason} = error ->
          if row = Repo.get(__MODULE__, "primary", log: false),
            do: save(row, error: Atom.to_string(reason))

          error
      end
    end)
  end

  def run(_, _, _), do: {:error, :invalid_transition}

  def restore_for_disconnect(config, token) do
    if Repo.get(__MODULE__, "primary", log: false) do
      case run(config, token, "disable") do
        {:ok, %{state: "disabled"}} -> :ok
        error -> error
      end
    else
      :ok
    end
  end

  defp prepare(row, config, token) do
    with {:ok, row} <- specifications(row, config, token),
         {:ok, filters} <- FilterProvider.list(config, token),
         :ok <- originals_unchanged(row, filters),
         {:ok, row} <- each_filter(row, fn row, key -> create_one(row, key, config, token) end),
         {:ok, row} <- inspect_filters(save(row, state: "active"), config, token) do
      {:ok, row}
    end
  end

  defp specifications(%{label_id: nil} = row, config, token) do
    with {:ok, label} <- FilterMail.label(config, token, row.nonce) do
      criteria = %{
        "from" => "robertguss@gmail.com",
        "to" => config[:allowed_email],
        "subject" => "phase0-filter-trash-001",
        "query" => "\"postman-probe-#{row.nonce}\""
      }

      entries =
        Map.new(
          [
            {"trash", %{"addLabelIds" => ["TRASH"]}},
            {"hold", %{"addLabelIds" => [label], "removeLabelIds" => ["INBOX"]}}
          ],
          fn {key, action} ->
            {key,
             %{"state" => "planned", "spec" => %{"criteria" => criteria, "action" => action}}}
          end
        )

      {:ok, save(row, label_id: label, entries: entries)}
    end
  end

  defp specifications(row, _, _), do: {:ok, row}

  defp create_one(row, key, config, token) do
    entry = row.entries[key]

    with {:ok, filters} <- FilterProvider.list(config, token),
         :ok <- originals_unchanged(row, filters),
         {:ok, found} <- resolve(row, entry, filters) do
      cond do
        found ->
          {:ok,
           put_entry(row, key, Map.merge(entry, %{"id" => found["id"], "state" => "active"}))}

        entry["state"] != "planned" ->
          {:error, :filter_creation_uncertain}

        true ->
          row = put_entry(row, key, Map.put(entry, "state", "creating"))

          case FilterProvider.create(
                 Keyword.put(config, :filter_lab_label_id, row.label_id),
                 token,
                 entry["spec"]
               ) do
            {:ok, filter} ->
              if filter["id"] in row.baseline_ids do
                {:error, :filter_drift}
              else
                {:ok,
                 put_entry(
                   row,
                   key,
                   Map.merge(entry, %{"id" => filter["id"], "state" => "active"})
                 )}
              end

            {:error, reason} = error ->
              # Definite rejection can be retried after authorization is repaired.
              if reason in [
                   :missing_scope,
                   :permission_denied,
                   :api_disabled,
                   :reconnect_required
                 ],
                 do: put_entry(row, key, entry)

              error
          end
      end
    end
  end

  defp disable(row, config, token) do
    row = save(row, state: "disabling")

    with {:ok, row} <-
           each_filter(
             row,
             fn row, key -> delete_one(row, key, config, token) end,
             ~w(hold trash)
           ),
         {:ok, filters} <- FilterProvider.list(config, token),
         row = record_baseline_change(row, filters),
         :ok <- all_absent(row, filters),
         {:ok, row} <- snapshot_mail(row, config, token),
         {:ok, row} <- restore_mail(row, config, token),
         :ok <- no_eligible_held_mail(row, config, token) do
      {:ok, save(row, state: "disabled")}
    end
  end

  defp delete_one(row, key, config, token) do
    entry = row.entries[key]

    with {:ok, filters} <- FilterProvider.list(config, token),
         {:ok, found} <- resolve(row, entry, filters) do
      cond do
        found ->
          entry = Map.merge(entry, %{"id" => found["id"], "state" => "deleting"})
          row = put_entry(row, key, entry)

          with :ok <- FilterProvider.delete(config, token, found["id"]),
               {:ok, current} <- FilterProvider.list(config, token),
               {:ok, nil} <- resolve(row, entry, current) do
            {:ok, put_entry(row, key, Map.put(entry, "state", "deleted"))}
          else
            {:ok, _} -> {:error, :filter_cleanup_pending}
            error -> error
          end

        entry["state"] == "creating" ->
          {:error, :filter_creation_uncertain}

        true ->
          {:ok, put_entry(row, key, Map.put(entry, "state", "deleted"))}
      end
    end
  end

  defp resolve(row, entry, filters) do
    candidates =
      Enum.filter(filters, fn f ->
        f["id"] not in row.baseline_ids and normalized(f) == normalized(entry["spec"])
      end)

    saved = Enum.find(filters, &(&1["id"] == entry["id"]))

    cond do
      saved && normalized(saved) != normalized(entry["spec"]) -> {:error, :filter_drift}
      length(candidates) > 1 -> {:error, :filter_ownership_uncertain}
      saved -> {:ok, saved}
      candidates != [] && entry["id"] -> {:error, :filter_drift}
      candidates != [] -> {:ok, hd(candidates)}
      true -> {:ok, nil}
    end
  end

  defp inspect_filters(%{state: "disabled"} = row, config, token) do
    with {:ok, filters} <- FilterProvider.list(config, token),
         row = record_baseline_change(row, filters),
         :ok <- all_absent(row, filters),
         :ok <- no_eligible_held_mail(row, config, token) do
      {:ok, row}
    end
  end

  defp inspect_filters(row, config, token) do
    with {:ok, filters} <- FilterProvider.list(config, token),
         :ok <- originals_unchanged(row, filters),
         true <- row.state == "active" and map_size(row.entries) == 2,
         true <-
           Enum.all?(row.entries, fn {_, e} ->
             case resolve(row, e, filters) do
               {:ok, %{"id" => id}} -> id == e["id"]
               _ -> false
             end
           end),
         {:ok, messages} <- FilterMail.messages(config, token, row.nonce) do
      {:ok, save(row, observed: length(messages), excluded: Enum.count(messages, &excluded?/1))}
    else
      false -> {:error, :filter_drift}
      error -> error
    end
  end

  defp no_eligible_held_mail(%{label_id: nil}, _, _), do: :ok

  defp no_eligible_held_mail(row, config, token) do
    with {:ok, messages} <- FilterMail.held_messages(config, token, row.label_id) do
      if Enum.all?(messages, &excluded?/1), do: :ok, else: {:error, :filter_cleanup_pending}
    end
  end

  defp all_absent(row, filters) do
    if Enum.all?(row.entries, fn {_, e} -> resolve(row, e, filters) == {:ok, nil} end),
      do: :ok,
      else: {:error, :filter_cleanup_pending}
  end

  defp snapshot_mail(%{label_id: nil} = row, _, _), do: {:ok, row}

  defp snapshot_mail(row, config, token) do
    with {:ok, messages} <- FilterMail.held_messages(config, token, row.label_id) do
      {:ok,
       save(row,
         mail: Map.merge(Map.new(messages, &{&1["id"], "pending"}), row.mail)
       )}
    end
  end

  defp restore_mail(row, config, token) do
    Enum.reduce_while(Enum.sort(Map.keys(row.mail)), {:ok, row}, fn id, {:ok, row} ->
      with {:ok, message} <- Google.controlled_message(config, token, id) do
        if excluded?(message) do
          {:cont, {:ok, save(row, mail: Map.put(row.mail, id, "excluded"))}}
        else
          case Projection.reconcile(
                 config,
                 token,
                 id,
                 row.label_id,
                 false,
                 row.mail[id] != "restored"
               ) do
            :ok -> {:cont, {:ok, save(row, mail: Map.put(row.mail, id, "restored"))}}
            error -> {:halt, error}
          end
        end
      else
        error -> {:halt, error}
      end
    end)
  end

  defp excluded?(message), do: Enum.any?(~w(TRASH SPAM DRAFT), &(&1 in message["labelIds"]))

  defp record_baseline_change(row, filters) do
    if originals_unchanged(row, filters) == :ok,
      do: row,
      else: save(row, baseline_changed: true)
  end

  defp originals_unchanged(row, filters) do
    if fingerprint(Enum.filter(filters, &(&1["id"] in row.baseline_ids))) == row.baseline_digest,
      do: :ok,
      else: {:error, :filter_baseline_changed}
  end

  defp normalized(f), do: Map.take(f, ["criteria", "action"])

  defp fingerprint(filters),
    do:
      :crypto.hash(:sha256, :erlang.term_to_binary(Enum.sort_by(filters, & &1["id"])))
      |> Base.encode16()

  defp each_filter(row, operation, order \\ ~w(trash hold)) do
    Enum.reduce_while(
      Enum.filter(order, &Map.has_key?(row.entries, &1)),
      {:ok, row},
      fn key, {:ok, row} ->
        case operation.(row, key) do
          {:ok, row} -> {:cont, {:ok, row}}
          error -> {:halt, error}
        end
      end
    )
  end

  defp put_entry(row, key, entry), do: save(row, entries: Map.put(row.entries, key, entry))
  defp save(row, fields), do: row |> Ecto.Changeset.change(fields) |> Repo.update!(log: false)

  defp summarize(nil),
    do: %{
      state: "not_started",
      baseline_changed: false,
      error: nil,
      marker: nil,
      filters: 0,
      pending: 0,
      observed: 0,
      restored: 0,
      excluded: 0
    }

  defp summarize(row) do
    %{
      state: row.state,
      baseline_changed: row.baseline_changed,
      error: row.error,
      marker: "postman-probe-#{row.nonce}",
      filters: Enum.count(row.entries, fn {_, e} -> e["state"] in ["active", "deleting"] end),
      pending:
        Enum.count(row.entries, fn {_, e} -> e["state"] in ["planned", "creating", "deleting"] end) +
          Enum.count(row.mail, fn {_, state} -> state == "pending" end),
      observed: row.observed,
      restored: Enum.count(row.mail, fn {_, state} -> state == "restored" end),
      excluded: max(row.excluded, Enum.count(row.mail, fn {_, state} -> state == "excluded" end))
    }
  end
end
