defmodule EmailSucks.Gmail.TrialDurabilityTest do
  use ExUnit.Case, async: false
  import Ecto.Query
  alias Ecto.Adapters.SQL.Sandbox
  alias EmailSucks.{Gmail, Repo}
  alias EmailSucks.Gmail.{Account, FilterExperiment, FilterProfile, Trial, TrialRun}

  setup do
    :ok = Sandbox.checkout(Repo, sandbox: false)
    previous = Application.get_env(:email_sucks, :gmail)

    config = [
      allowed_email: "owner@gmail.com",
      vault_key: String.duplicate("k", 64),
      http_options: [plug: {Req.Test, __MODULE__}]
    ]

    Application.put_env(:email_sucks, :gmail, config)

    {:ok, session} =
      Gmail.connect(%{subject: "subject", email: "owner@gmail.com"}, %{
        "access_token" => "test",
        "refresh_token" => "refresh",
        "expires_at" => Trial.now() + 3600
      })

    Repo.insert!(%Trial{id: "primary", state: "active", next_due: Trial.now() + 300}, log: false)

    specs =
      FilterProfile.specifications(
        Trial.profile(),
        "owner@gmail.com",
        String.duplicate("a", 32),
        "Label_trial"
      )

    filter = Map.put(specs["hold"], "id", "owned")

    Repo.insert!(
      %FilterExperiment{
        id: Trial.profile(),
        state: "active",
        nonce: String.duplicate("a", 32),
        label_id: "Label_trial",
        baseline_ids: [],
        baseline_digest: :crypto.hash(:sha256, :erlang.term_to_binary([])) |> Base.encode16(),
        entries: %{"hold" => %{"state" => "active", "id" => "owned", "spec" => specs["hold"]}}
      },
      log: false
    )

    {:ok, provider} = Agent.start_link(fn -> %{labels: ["Label_trial", "UNREAD"], writes: 0} end)

    on_exit(fn ->
      Sandbox.checkout(Repo, sandbox: false)
      Repo.delete_all(from(j in Oban.Job, where: j.queue == "gmail_delivery"), log: false)
      Repo.delete_all("gmail_trial_requests", log: false)
      Repo.delete_all(TrialRun, log: false)
      Repo.delete_all(Trial, log: false)
      Repo.delete_all(FilterExperiment, log: false)
      Repo.delete_all(Account, log: false)
      Sandbox.checkin(Repo)
      Application.put_env(:email_sucks, :gmail, previous)
    end)

    %{provider: provider, filter: filter, session: session}
  end

  test "failed run cancellation rolls back stop finalization and remains retryable" do
    run =
      Repo.insert!(
        %TrialRun{
          kind: "manual",
          state: "frozen",
          due_at: Trial.now(),
          entries: %{"m1" => %{"state" => "pending"}}
        },
        log: false
      )

    assert :ok = Trial.fence()

    Repo.query!(
      "ALTER TABLE gmail_trial_runs ADD CONSTRAINT trial_test_reject_cancel CHECK (state != 'cancelled')",
      [],
      log: false
    )

    try do
      assert_raise Postgrex.Error, fn -> Trial.finish_stop() end
      assert Repo.get!(Trial, "primary", log: false).state == "stopping"
      assert Repo.get!(TrialRun, run.id, log: false).state == "frozen"
    after
      Repo.query!("ALTER TABLE gmail_trial_runs DROP CONSTRAINT trial_test_reject_cancel", [],
        log: false
      )
    end

    assert :ok = Trial.finish_stop()
    assert Repo.get!(Trial, "primary", log: false).state == "stopped"
    assert Repo.get!(TrialRun, run.id, log: false).state == "cancelled"
    assert Repo.get!(TrialRun, run.id, log: false).entries == run.entries
  end

  test "HTTP Check Now joins a provider-blocked run and respects the stop fence", ctx do
    {:ok, run} = Trial.request(Ecto.UUID.generate())
    due = Repo.get!(Trial, "primary", log: false).next_due
    future = Repo.insert!(%TrialRun{kind: "scheduled", due_at: due}, log: false)
    parent = self()

    Req.Test.stub(__MODULE__, fn _conn ->
      send(parent, :provider_blocked)

      receive do
        :never -> :never
      end
    end)

    {pid, monitor} =
      spawn_monitor(fn ->
        Sandbox.checkout(Repo, sandbox: false)

        receive do
          :start -> Gmail.execute_trial(run.id)
        end
      end)

    Req.Test.allow(__MODULE__, self(), pid)
    send(pid, :start)
    assert_receive :provider_blocked, 3000

    try do
      first = Ecto.UUID.generate()

      for request <- [first, first, Ecto.UUID.generate()] do
        conn =
          Phoenix.ConnTest.build_conn()
          |> Plug.Test.init_test_session(gmail_session: ctx.session)
          |> Plug.Conn.put_private(:plug_skip_csrf_protection, true)
          |> Phoenix.ConnTest.dispatch(EmailSucksWeb.Endpoint, :post, "/gmail/trial/check-now", %{
            request_id: request
          })

        assert conn.status == 200
        assert Jason.decode!(conn.resp_body)["running"]
      end

      ids = Repo.all(from(r in "gmail_trial_requests", select: r.run_id), log: false)
      assert length(ids) == 3
      assert Enum.uniq(ids) == [Ecto.UUID.dump!(run.id)]
      assert Repo.get!(Trial, "primary", log: false).next_due == due
      assert Repo.get!(TrialRun, future.id, log: false).state == "planned"

      # Completion racing a retry preserves its receipt; a new request cannot turn
      # the future scheduled occurrence into a manual delivery while the lock is busy.
      Repo.get!(TrialRun, run.id, log: false)
      |> Ecto.Changeset.change(state: "complete")
      |> Repo.update!(log: false)

      assert {:ok, completed} = Trial.request(first)
      assert completed.id == run.id
      assert completed.state == "complete"
      assert {:error, :operation_in_progress} = Trial.request(Ecto.UUID.generate())
      assert Repo.get!(TrialRun, future.id, log: false).state == "planned"

      Repo.get!(Trial, "primary", log: false)
      |> Ecto.Changeset.change(state: "stopping", next_due: nil)
      |> Repo.update!(log: false)

      assert {:error, :invalid_transition} =
               Gmail.trial_check_now(ctx.session, Ecto.UUID.generate())

      assert Repo.aggregate("gmail_trial_requests", :count, log: false) == 3
    after
      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^monitor, :process, ^pid, :killed}, 3000
    end
  end

  test "process death after provider acceptance preserves commits; restarted Lifeline rescues intent and retry reads before writing",
       ctx do
    Gmail.logout(ctx.session)
    parent = self()

    Req.Test.stub(__MODULE__, fn conn ->
      case {conn.method, conn.request_path} do
        {"GET", "/gmail/v1/users/me/settings/filters"} ->
          Req.Test.json(conn, %{"filter" => [ctx.filter]})

        {"GET", "/gmail/v1/users/me/messages"} ->
          ids =
            if URI.decode_query(conn.query_string)["labelIds"], do: [%{"id" => "m1"}], else: []

          Req.Test.json(conn, %{"messages" => ids})

        {"GET", "/gmail/v1/users/me/messages/m1"} ->
          labels = Agent.get(ctx.provider, & &1.labels)

          Req.Test.json(conn, %{
            "id" => "m1",
            "labelIds" => labels,
            "payload" => %{
              "headers" => [
                %{"name" => "From", "value" => "robertguss@gmail.com"},
                %{"name" => "To", "value" => "owner@gmail.com"},
                %{"name" => "Subject", "value" => FilterProfile.subject(Trial.profile())}
              ]
            }
          })

        {"POST", "/gmail/v1/users/me/messages/m1/modify"} ->
          Agent.update(ctx.provider, &%{&1 | labels: ["INBOX", "UNREAD"], writes: &1.writes + 1})
          send(parent, :provider_accepted)

          receive do
            :never -> Req.Test.json(conn, %{"id" => "m1"})
          end
      end
    end)

    request_id = Ecto.UUID.generate()
    {:ok, run} = Trial.request(request_id)
    [job] = Repo.all(from(j in Oban.Job, where: j.queue == "gmail_delivery"), log: false)
    assert job.args == %{"run_id" => run.id}
    # An executing attempt is durable before worker code. Use the production worker entrypoint.
    Repo.update_all(
      from(j in Oban.Job, where: j.id == ^job.id),
      [
        set: [
          state: "executing",
          attempt: 1,
          attempted_at: DateTime.add(DateTime.utc_now(), -301)
        ]
      ],
      log: false
    )

    {pid, monitor} =
      spawn_monitor(fn ->
        Sandbox.checkout(Repo, sandbox: false)

        receive do
          :start -> EmailSucks.Gmail.TrialWorker.perform(job)
        end
      end)

    Req.Test.allow(__MODULE__, self(), pid)
    send(pid, :start)
    assert_receive :provider_accepted, 5000
    saved = Repo.get!(TrialRun, run.id, log: false)
    assert saved.state == "frozen"
    assert saved.entries == %{"m1" => %{"state" => "pending"}}
    assert {:error, :operation_in_progress} = Gmail.execute_trial(run.id)
    # Independent caller joins the provider-blocked generation without acquiring its
    # account lock, creating a new run, or consuming the future scheduled occurrence.
    due = Repo.get!(Trial, "primary", log: false).next_due
    future = Repo.insert!(%TrialRun{kind: "scheduled", due_at: due}, log: false)
    first_request = Ecto.UUID.generate()
    second_request = Ecto.UUID.generate()
    assert {:ok, joined} = Trial.request(first_request)
    assert joined.id == run.id
    assert {:ok, again} = Trial.request(first_request)
    assert again.id == run.id
    assert {:ok, other} = Trial.request(second_request)
    assert other.id == run.id
    assert Repo.aggregate(TrialRun, :count, log: false) == 2
    assert Repo.get!(TrialRun, future.id, log: false).state == "planned"
    assert Repo.get!(Trial, "primary", log: false).next_due == due

    assert Repo.aggregate(from(j in Oban.Job, where: j.queue == "gmail_delivery"), :count,
             log: false
           ) == 1

    assert Repo.aggregate("gmail_trial_requests", :count, log: false) == 3
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^pid, :killed}, 3000

    # Start, stop, and restart an independent Oban supervisor; invoke the installed Lifeline.
    opts = [
      name: TrialRescueOban,
      repo: Repo,
      queues: false,
      plugins: [],
      lifeline: [interval: 60_000, rescue_after: {5, :minutes}],
      peer: Oban.Peers.Isolated,
      testing: :disabled
    ]

    first = start_supervised!({Oban, opts})
    assert Process.alive?(first)
    stop_supervised!(TrialRescueOban)
    second = start_supervised!({Oban, opts})
    assert second != first
    conf = Oban.config(TrialRescueOban)
    assert Oban.Peer.leader?(conf)

    {:noreply, state} =
      Oban.Lifeline.handle_info(:rescue, %Oban.Lifeline{
        conf: conf,
        rescue_after: 300_000,
        interval: 60_000
      })

    Process.cancel_timer(state.timer)
    assert Repo.get!(Oban.Job, job.id, log: false).state == "available"

    retry =
      Task.async(fn ->
        Sandbox.checkout(Repo, sandbox: false)

        receive do
          :retry -> EmailSucks.Gmail.TrialWorker.perform(job)
        end
      end)

    Req.Test.allow(__MODULE__, self(), retry.pid)
    send(retry.pid, :retry)
    assert Task.await(retry, 5000) == :ok
    assert Repo.get!(TrialRun, run.id, log: false).state == "complete"
    assert Agent.get(ctx.provider, & &1.writes) == 1
    assert {:ok, same} = Trial.request(request_id)
    assert same.id == run.id
    assert same.state == "complete"
  end
end
