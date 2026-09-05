defmodule EmailSucks.OperationalHealthTest do
  use EmailSucks.DataCase
  alias EmailSucks.{OperationalHealth, Repo}
  alias EmailSucks.Gmail.{Account, Batch, Controlled, FilterExperiment}

  test "missing worker queue cannot be hidden by an empty healthy mailbox" do
    assert %{healthy: false, failures: [:worker_queue_unavailable]} = OperationalHealth.check()
  end

  test "saved failed work is critical and output contains no mailbox identifiers or credentials" do
    Repo.insert!(%Account{
      id: "primary",
      subject: "private-subject",
      email: "private@example.test",
      credentials: "private-token",
      status: "reconnect_required",
      disconnect_phase: "restoring"
    })

    Repo.insert!(%Controlled{
      id: "primary",
      state: "release_pending",
      message_id: "private-message",
      label_id: "Label_private"
    })

    Repo.insert!(%Batch{
      id: "primary",
      state: "releasing",
      label_id: "Label_private",
      entries: %{
        "private-batch-id" => %{"state" => "release_pending", "error" => "private-provider-error"}
      }
    })

    Repo.insert!(%FilterExperiment{
      id: "primary",
      state: "active",
      nonce: "private-marker",
      baseline_ids: [],
      baseline_digest: "private-digest",
      error: "private-provider-error"
    })

    result = OperationalHealth.check()
    refute result.healthy
    assert :gmail_recovery_pending in result.failures
    assert :gmail_operation_failed in result.failures
    assert :gmail_access_unavailable in result.failures
    refute Jason.encode!(result) =~ "private"
  end

  test "intentional held mail with usable access is not failed work" do
    Repo.insert!(%Account{
      id: "primary",
      subject: "subject",
      email: "owner@example.test",
      status: "connected",
      credentials: "encrypted"
    })

    Repo.insert!(%Controlled{
      id: "primary",
      state: "held",
      message_id: "message",
      label_id: "Label_test"
    })

    Repo.insert!(%Batch{
      id: "primary",
      state: "held",
      label_id: "Label_test",
      entries: %{"id" => %{"state" => "held", "error" => nil}}
    })

    assert OperationalHealth.check().failures == [:worker_queue_unavailable]
  end

  test "unfinished batch finalization stays critical even after every message was confirmed" do
    Repo.insert!(%Batch{
      id: "primary",
      state: "releasing",
      label_id: "Label_test",
      entries: %{"id" => %{"state" => "released", "error" => nil}}
    })

    assert :gmail_recovery_pending in OperationalHealth.check().failures
  end

  test "historical baseline warnings after completed cleanup do not suppress recovery heartbeats" do
    Repo.insert!(%FilterExperiment{
      id: "primary",
      state: "disabled",
      nonce: "marker",
      baseline_ids: [],
      baseline_digest: "digest",
      baseline_changed: true
    })

    assert OperationalHealth.check().failures == [:worker_queue_unavailable]
  end

  test "ordinary arrival recovery remains visible after the primary experiment is disabled" do
    for {id, state} <- [{"primary", "disabled"}, {"arrival-primary-v1", "preparing"}] do
      Repo.insert!(%FilterExperiment{
        id: id,
        state: state,
        nonce: "marker",
        baseline_ids: [],
        baseline_digest: "digest",
        error: if(state == "preparing", do: "provider_error"),
        baseline_changed: true
      })
    end

    failures = OperationalHealth.check().failures
    assert :gmail_recovery_pending in failures
    assert :gmail_operation_failed in failures
    assert :gmail_access_unavailable in failures
    assert :gmail_filter_baseline_changed in failures

    Repo.get!(FilterExperiment, "arrival-primary-v1")
    |> Ecto.Changeset.change(state: "disabled", error: nil)
    |> Repo.update!()

    assert OperationalHealth.check().failures == [:worker_queue_unavailable]
  end

  test "unsupported filter ownership cannot hide blocked recovery behind healthy known profiles" do
    Repo.insert!(%FilterExperiment{
      id: "unsupported-profile",
      state: "active",
      nonce: "private-marker",
      baseline_ids: [],
      baseline_digest: "private-digest"
    })

    assert FilterExperiment.recovery_required?()
    assert FilterExperiment.restore_for_disconnect([], "unused") == {:error, :invalid_transition}
    result = OperationalHealth.check()
    assert :gmail_recovery_pending in result.failures
    assert :gmail_operation_failed in result.failures
    refute Jason.encode!(result) =~ "unsupported-profile"
    refute Jason.encode!(result) =~ "private"
  end

  test "persisted read-only history failure is visible without exposing cursor or message IDs" do
    Repo.insert!(%EmailSucks.Gmail.HistoryProbe{
      id: "primary",
      message_ids: ["private-message"],
      cursor: "private-cursor",
      error: "provider_unavailable"
    })

    result = OperationalHealth.check()
    assert :gmail_operation_failed in result.failures
    refute Jason.encode!(result) =~ "private"
  end

  test "completed disconnect retires history failure from health while preserving its checkpoint" do
    old = Application.get_env(:email_sucks, :gmail)

    Application.put_env(:email_sucks, :gmail,
      allowed_email: "owner@example.test",
      vault_key: String.duplicate("k", 64),
      http_options: [plug: {Req.Test, __MODULE__}]
    )

    on_exit(fn ->
      if old,
        do: Application.put_env(:email_sucks, :gmail, old),
        else: Application.delete_env(:email_sucks, :gmail)
    end)

    {:ok, session} =
      EmailSucks.Gmail.connect(%{subject: "subject", email: "owner@example.test"}, %{
        "access_token" => "private-access",
        "refresh_token" => "private-refresh",
        "expires_at" => System.system_time(:second) + 3600
      })

    checkpoint =
      Repo.insert!(%EmailSucks.Gmail.HistoryProbe{
        id: "primary",
        message_ids: ["private-message"],
        cursor: "private-cursor",
        observations: %{"private-message" => %{"available" => true, "label_ids" => ["INBOX"]}},
        checked_at: System.system_time(:second),
        revision: 2,
        mode: "incremental",
        error: "provider_unavailable"
      })

    for {status, phase} <- [
          {"connected", nil},
          {"reconnect_required", nil},
          {"connected", "restoring"},
          {"connected", "revoking"}
        ] do
      Repo.get!(Account, "primary")
      |> Ecto.Changeset.change(status: status, disconnect_phase: phase)
      |> Repo.update!()

      assert :gmail_operation_failed in OperationalHealth.check().failures
    end

    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.request_path == "/revoke"
      Plug.Conn.send_resp(conn, 200, "")
    end)

    assert {:ok, _} = EmailSucks.Gmail.disconnect(session)
    assert %{credentials: "", disconnect_phase: nil} = Repo.get!(Account, "primary")
    assert OperationalHealth.check().failures == [:worker_queue_unavailable]
    assert Repo.get!(EmailSucks.Gmail.HistoryProbe, "primary") == checkpoint
  end

  for state <- ~w(available scheduled retryable executing discarded) do
    test "#{state} jobs distinguish overdue work from future work" do
      now = DateTime.utc_now()
      state = unquote(state)

      job =
        Repo.insert!(%Oban.Job{
          worker: "EmailSucks.Probe",
          queue: "phase_zero",
          state: state,
          scheduled_at: DateTime.add(now, 600),
          attempted_at: now
        })

      assert :jobs_unresolved in OperationalHealth.check().failures == (state == "discarded")

      job
      |> Ecto.Changeset.change(
        scheduled_at: DateTime.add(now, -301),
        attempted_at: DateTime.add(now, -301)
      )
      |> Repo.update!()

      assert :jobs_unresolved in OperationalHealth.check().failures
      job |> Ecto.Changeset.change(state: "completed") |> Repo.update!()
      refute :jobs_unresolved in OperationalHealth.check().failures
    end
  end

  test "overdue trial and failed manual intent are unhealthy but retained stopped history is not" do
    trial =
      Repo.insert!(%EmailSucks.Gmail.Trial{
        id: "primary",
        state: "active",
        next_due: System.system_time(:second) - 301
      })

    assert :jobs_unresolved in OperationalHealth.check().failures

    trial
    |> Ecto.Changeset.change(
      next_due: System.system_time(:second) + 300,
      error: "provider_unavailable"
    )
    |> Repo.update!()

    assert :gmail_operation_failed in OperationalHealth.check().failures

    Repo.insert!(%EmailSucks.Gmail.TrialRun{
      kind: "manual",
      state: "frozen",
      due_at: System.system_time(:second),
      error: "provider_unavailable"
    })

    assert :jobs_unresolved in OperationalHealth.check().failures
    trial |> Ecto.Changeset.change(state: "stopped", next_due: nil, error: nil) |> Repo.update!()
    assert OperationalHealth.check().failures == [:worker_queue_unavailable]
  end
end
