defmodule EmailSucks.Gmail.Trial do
  @moduledoc "One explicitly started, five-minute, fixed-fixture delivery trial."
  use Ecto.Schema
  import Ecto.Query
  alias EmailSucks.Repo

  alias EmailSucks.Gmail.{
    Controlled,
    FilterExperiment,
    FilterMail,
    FilterProfile,
    Google,
    Projection,
    TrialRun,
    TrialWorker
  }

  @profile "delivery-trial-v1"
  @capacity 20
  @primary_key {:id, :string, autogenerate: false}
  schema "gmail_trials" do
    field :state, :string
    field :next_due, :integer
    field :error, :string
  end

  def profile, do: @profile
  def now, do: System.system_time(:second)
  def active?, do: match?(%{state: "active"}, Repo.get(__MODULE__, "primary", log: false))

  def latest do
    Repo.one(
      from(r in TrialRun,
        where: r.entries != ^%{},
        order_by: [desc: r.due_at, desc: r.id],
        limit: 1
      ),
      log: false
    )
  end

  def summary(config) do
    row = Repo.get(__MODULE__, "primary", log: false)
    filter = Repo.get(FilterExperiment, @profile, log: false)
    latest = latest()

    %{
      state: if(row, do: row.state, else: "not_started"),
      next_due:
        if(row && row.next_due,
          do: DateTime.from_unix!(row.next_due) |> DateTime.to_iso8601(),
          else: nil
        ),
      error: row && row.error,
      latest_run_id: latest && latest.id,
      running: row != nil and row.state == "active" and unfinished() != nil,
      latest_run_state: latest && latest.state,
      instructions:
        if(row && row.state == "active" && filter && filter.state == "active",
          do: %{
            sender: "robertguss@gmail.com",
            recipient: config[:allowed_email],
            subject: FilterProfile.subject(@profile),
            marker: "postman-probe-#{filter.nonce}"
          },
          else: nil
        )
    }
  end

  def start(config, token) do
    Controlled.exclusive(fn ->
      row = Repo.get(__MODULE__, "primary", log: false)

      cond do
        row && row.state == "active" ->
          {:ok, summary(config)}

        row && row.state != "starting" ->
          {:error, :invalid_transition}

        true ->
          row = row || Repo.insert!(%__MODULE__{id: "primary", state: "starting"}, log: false)
          filter = Repo.get(FilterExperiment, @profile, log: false)
          action = if(filter, do: "recover", else: "activate")

          case FilterExperiment.run(config, token, action, @profile) do
            {:ok, %{state: "active"}} ->
              Repo.transaction(fn ->
                due = now() + 300
                save(row, state: "active", next_due: due, error: nil)
                enqueue("scheduled", due)
              end)

              {:ok, summary(config)}

            {:error, reason} = error ->
              save(row, error: Atom.to_string(reason))
              error

            _ ->
              {:error, :invalid_transition}
          end
      end
    end)
  end

  def request(request_id) do
    with {:ok, uuid} <- Ecto.UUID.cast(request_id) do
      case Controlled.exclusive(fn -> request_receipt(uuid, true) end) do
        {:error, :operation_in_progress} -> request_receipt(uuid, false)
        result -> result
      end
    else
      _ -> {:error, :stale}
    end
  end

  defp request_receipt(uuid, may_enqueue?) do
    Repo.transaction(fn ->
      # This short row lock serializes receipts with the persisted stop fence. It never
      # covers provider I/O, and the busy-account path cannot create a run or a job.
      trial =
        Repo.one(from(t in __MODULE__, where: t.id == "primary", lock: "FOR UPDATE"), log: false)

      unless trial && trial.state == "active", do: Repo.rollback(:invalid_transition)
      binary = Ecto.UUID.dump!(uuid)

      saved =
        Repo.one(from(r in "gmail_trial_requests", where: r.id == ^binary, select: r.run_id),
          log: false
        )

      run =
        if saved do
          Repo.get!(TrialRun, Ecto.UUID.load!(saved), log: false)
        else
          unfinished() ||
            if(may_enqueue?,
              do: enqueue("manual", now()),
              else: Repo.rollback(:operation_in_progress)
            )
        end

      if may_enqueue? and run.state in ["planned", "frozen"], do: ensure_enqueued(run)

      unless saved do
        Repo.insert_all("gmail_trial_requests", [%{id: binary, run_id: Ecto.UUID.dump!(run.id)}],
          log: false
        )
      end

      run
    end)
  end

  defp unfinished do
    Repo.one(
      from(r in TrialRun,
        where: r.state in ["planned", "frozen"] and (r.kind == "manual" or r.due_at <= ^now()),
        order_by: [asc: r.due_at, asc: r.id],
        limit: 1
      ),
      log: false
    )
  end

  defp ensure_enqueued(run) do
    args = %{"run_id" => run.id}

    unless Repo.exists?(
             from(j in Oban.Job,
               where:
                 j.worker == "EmailSucks.Gmail.TrialWorker" and j.args == ^args and
                   j.state in ["available", "scheduled", "retryable", "executing"]
             ),
             log: false
           ) do
      {:ok, _} = args |> TrialWorker.new() |> Oban.insert()
    end
  end

  defp enqueue(kind, due) do
    run = Repo.insert!(%TrialRun{kind: kind, due_at: due}, log: false)

    {:ok, _} =
      %{run_id: run.id}
      |> TrialWorker.new(scheduled_at: DateTime.from_unix!(due))
      |> Oban.insert()

    run
  end

  def fence do
    Controlled.exclusive(fn ->
      case Repo.get(__MODULE__, "primary", log: false) do
        nil ->
          :ok

        %{state: "stopped"} ->
          :ok

        row ->
          save(row, state: "stopping", next_due: nil)
          :ok
      end
    end)
  end

  def stop(config, token) do
    Controlled.exclusive(fn ->
      case Repo.get(__MODULE__, "primary", log: false) do
        nil ->
          {:error, :invalid_transition}

        %{state: "stopped"} ->
          {:ok, summary(config)}

        _ ->
          :ok = fence()

          # No filter writes can precede its durable journal. A starting intent
          # may therefore be abandoned without provider cleanup when it is absent.
          cleanup =
            case Repo.get(FilterExperiment, @profile, log: false) do
              nil ->
                :ok

              _ ->
                with {:ok, %{state: "disabled"}} <-
                       FilterExperiment.run(config, token, "disable", @profile),
                     do: :ok
            end

          case cleanup do
            :ok ->
              finish_stop()
              {:ok, summary(config)}

            {:error, reason} = error ->
              fail(reason)
              error
          end
      end
    end)
  end

  def finish_stop do
    {:ok, :ok} =
      Repo.transaction(fn ->
        case Repo.get(__MODULE__, "primary", log: false) do
          nil ->
            :ok

          row ->
            save(row, state: "stopped", next_due: nil, error: nil)

            Repo.update_all(
              from(r in TrialRun, where: r.state in ["planned", "frozen"]),
              [set: [state: "cancelled"]],
              log: false
            )

            :ok
        end
      end)

    :ok
  end

  def fail(reason) do
    if row = Repo.get(__MODULE__, "primary", log: false),
      do: save(row, error: Atom.to_string(reason))

    {:error, reason}
  end

  def execute(config, token, id) do
    Controlled.exclusive(fn ->
      with true <- active?(),
           {:ok, id} <- Ecto.UUID.cast(id),
           %TrialRun{} = run <- Repo.get(TrialRun, id, log: false),
           true <- run.due_at <= now(),
           %FilterExperiment{state: "active"} = filter <-
             Repo.get(FilterExperiment, @profile, log: false) do
        case run.state do
          "complete" ->
            {:ok, run}

          "cancelled" ->
            {:error, :invalid_transition}

          _ ->
            with :ok <- turn(run),
                 {:ok, run} <- freeze(run, filter, config, token),
                 {:ok, run} <- release(run, config, token) do
              Repo.transaction(fn ->
                run = save(run, state: "complete", completed_at: now(), error: nil)
                trial = Repo.get!(__MODULE__, "primary", log: false)

                if run.kind == "scheduled" do
                  # Preserve the original cadence, coalescing missed windows.
                  due = run.due_at + (div(max(now() - run.due_at, 0), 300) + 1) * 300
                  save(trial, next_due: due, error: nil)
                  enqueue("scheduled", due)
                else
                  save(trial, error: nil)
                end

                run
              end)
            else
              {:error, reason} = error ->
                save(Repo.get!(TrialRun, id, log: false), error: Atom.to_string(reason))
                fail(reason)
                error
            end
        end
      else
        _ -> {:error, :invalid_transition}
      end
    end)
  end

  defp turn(run) do
    case unfinished() do
      %{id: id} when id != run.id -> {:error, :operation_in_progress}
      _ -> :ok
    end
  end

  defp freeze(%{state: "frozen"} = run, _, _, _), do: {:ok, run}

  defp freeze(run, filter, config, token) do
    with {:ok, %{state: "active"}} <- FilterExperiment.run(config, token, "inspect", @profile),
         {:ok, messages} <- FilterMail.held_messages(config, token, filter.label_id, @profile),
         true <- length(messages) <= @capacity do
      entries =
        Map.new(messages, fn m ->
          {m["id"], %{"state" => if(excluded?(m), do: "excluded", else: "pending")}}
        end)

      {:ok, save(run, state: "frozen", label_id: filter.label_id, entries: entries)}
    else
      false -> {:error, :batch_capacity_exceeded}
      error -> error
    end
  end

  defp release(run, config, token) do
    Enum.reduce_while(Enum.sort(Map.keys(run.entries)), {:ok, run}, fn id, {:ok, current} ->
      entry = current.entries[id]

      result =
        if entry["state"] in ["released", "excluded", "gone"] do
          {:ok, entry["state"]}
        else
          case Google.controlled_message(config, token, id) do
            {:ok, message} ->
              if excluded?(message) do
                {:ok, "excluded"}
              else
                case Projection.reconcile(config, token, id, current.label_id, false, true) do
                  :ok -> {:ok, "released"}
                  error -> error
                end
              end

            {:error, :not_found} ->
              {:ok, "gone"}

            error ->
              error
          end
        end

      case result do
        {:ok, state} ->
          {:cont,
           {:ok, save(current, entries: Map.put(current.entries, id, %{"state" => state}))}}

        error ->
          {:halt, error}
      end
    end)
  end

  defp excluded?(message), do: Enum.any?(~w(TRASH SPAM DRAFT), &(&1 in message["labelIds"]))
  defp save(row, fields), do: row |> Ecto.Changeset.change(fields) |> Repo.update!(log: false)
end
