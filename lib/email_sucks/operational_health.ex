defmodule EmailSucks.OperationalHealth do
  @moduledoc "Read-only worker and saved-work health. Returns no account, message or job identifiers."
  import Ecto.Query
  alias EmailSucks.Repo
  alias EmailSucks.Gmail.{Account, Batch, Controlled, FilterExperiment, FilterProfile}

  def check do
    controlled = Controlled.summary()
    batch = Batch.summary()
    filters = FilterExperiment.summaries() |> Map.values()
    known_profiles = FilterProfile.ids()

    unsupported_filters =
      Repo.exists?(from(f in FilterExperiment, where: f.id not in ^known_profiles), log: false)

    account = Repo.get(Account, "primary", log: false)
    queue = Oban.check_queue(queue: :phase_zero)
    cutoff = DateTime.add(DateTime.utc_now(), -300)

    unresolved =
      Repo.exists?(
        from(j in Oban.Job,
          where:
            j.queue == "phase_zero" and
              (j.state == "discarded" or
                 (j.state in ["available", "scheduled", "retryable"] and j.scheduled_at < ^cutoff) or
                 (j.state == "executing" and j.attempted_at < ^cutoff))
        ),
        log: false
      )

    recovery =
      unsupported_filters or controlled.state in ["hold_pending", "release_pending"] or
        batch.pending > 0 or
        batch.state in ["holding", "releasing"] or
        Enum.any?(filters, &(&1.state in ["preparing", "disabling"])) or
        (account != nil and account.disconnect_phase != nil)

    mail_at_risk =
      unsupported_filters or controlled.state not in ["not_started", "released"] or batch.held > 0 or
        batch.pending > 0 or
        batch.state in ["holding", "releasing"] or
        Enum.any?(filters, &(&1.state not in ["not_started", "disabled"]))

    access_missing =
      mail_at_risk and
        (account == nil or account.status != "connected" or account.credentials == "")

    failed =
      unsupported_filters or batch.errors > 0 or
        Enum.any?(filters, &(&1.error not in [nil, "invalid_transition"]))

    failures =
      [
        worker_queue_unavailable: not match?(%{paused: false, limit: n} when n > 0, queue),
        jobs_unresolved: unresolved,
        gmail_recovery_pending: recovery,
        gmail_operation_failed: failed,
        gmail_access_unavailable: access_missing,
        gmail_filter_baseline_changed:
          Enum.any?(filters, &(&1.baseline_changed and &1.state != "disabled"))
      ]
      |> Enum.filter(&elem(&1, 1))
      |> Enum.map(&elem(&1, 0))

    %{healthy: failures == [], failures: failures}
  rescue
    _ -> %{healthy: false, failures: [:health_probe_unavailable]}
  catch
    :exit, _ -> %{healthy: false, failures: [:health_probe_unavailable]}
  end
end
