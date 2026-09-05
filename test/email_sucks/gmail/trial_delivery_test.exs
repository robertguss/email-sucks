defmodule EmailSucks.Gmail.TrialDeliveryTest do
  use EmailSucks.DataCase
  import Ecto.Query
  alias EmailSucks.{Gmail, Repo}

  alias EmailSucks.Gmail.{
    Account,
    FilterExperiment,
    FilterProfile,
    Trial,
    TrialRun,
    TrialView,
    TrialWorker
  }

  setup do
    old = Application.get_env(:email_sucks, :gmail)

    config = [
      allowed_email: "owner@gmail.com",
      client_id: "test",
      client_secret: "secret",
      redirect_uri: "http://localhost/callback",
      vault_key: String.duplicate("k", 64),
      http_options: [plug: {Req.Test, __MODULE__}]
    ]

    Application.put_env(:email_sucks, :gmail, config)
    on_exit(fn -> Application.put_env(:email_sucks, :gmail, old) end)
    Process.put(:mail, %{})
    Process.put(:writes, [])
    Process.put(:filters, [])
    Process.put(:labels, [])
    Req.Test.stub(__MODULE__, &provider/1)

    {:ok, session} =
      Gmail.connect(%{subject: "subject", email: "owner@gmail.com"}, %{
        "access_token" => "test",
        "refresh_token" => "refresh",
        "scope" =>
          "https://www.googleapis.com/auth/gmail.modify https://www.googleapis.com/auth/gmail.settings.basic",
        "expires_at" => Trial.now() + 3600
      })

    %{config: config, session: session}
  end

  test "start persists authority before provider writes and creates a single future UUID job",
       ctx do
    prior = disabled_primary()
    assert {:ok, %{state: "active", instructions: instructions}} = Gmail.trial_start(ctx.session)
    assert instructions.subject == "phase0-delivery-trial-001"
    assert instructions.marker =~ "postman-probe-"
    assert Repo.get!(FilterExperiment, "primary") == prior
    assert length(Process.get(:filters)) == 1
    assert {:ok, %{state: "active"}} = Gmail.trial_start(ctx.session)
    [run] = Repo.all(TrialRun)
    assert run.kind == "scheduled"
    assert run.due_at in (Trial.now() + 299)..(Trial.now() + 300)
    [job] = jobs()
    assert job.args == %{"run_id" => run.id}
    assert DateTime.compare(job.scheduled_at, DateTime.from_unix!(run.due_at)) == :eq
    assert TrialWorker.timeout(job) == 55_000
  end

  test "background release works after logout, freezes arrival set, excludes Trash, preserves unread",
       ctx do
    active()

    Process.put(:mail, %{
      "m1" => ["Label_trial", "UNREAD", "STARRED"],
      "m2" => ["Label_trial", "TRASH", "UNREAD"]
    })

    {:ok, run} = Trial.request(Ecto.UUID.generate())
    Process.put(:late_arrival, true)
    Gmail.logout(ctx.session)
    assert Gmail.account(ctx.session) == nil
    assert {:ok, completed} = Gmail.execute_trial(run.id)
    assert completed.state == "complete"
    assert Enum.sort(Map.keys(completed.entries)) == ["m1", "m2"]
    assert completed.entries["m2"]["state"] == "excluded"
    assert Process.get(:writes) == ["m1"]
    assert Enum.sort(Process.get(:mail)["m1"]) == ~w(INBOX STARRED UNREAD)
    assert Process.get(:mail)["late"] == ["Label_trial", "UNREAD"]
    assert {:ok, _} = Gmail.execute_trial(run.id)
    assert Process.get(:writes) == ["m1"]
  end

  test "lost modify response resumes frozen membership by readback with no duplicate write" do
    active()
    Process.put(:mail, %{"m1" => ["Label_trial", "UNREAD"]})
    {:ok, run} = Trial.request(Ecto.UUID.generate())
    Process.put(:lose_modify, true)
    assert {:error, :provider_unavailable} = Gmail.execute_trial(run.id)
    assert Repo.get!(TrialRun, run.id).state == "frozen"
    Process.put(:mail, Map.put(Process.get(:mail), "late", ["Label_trial", "UNREAD"]))
    assert {:ok, done} = Gmail.execute_trial(run.id)
    assert Map.keys(done.entries) == ["m1"]
    assert Process.get(:writes) == ["m1"]
    assert Trial.latest().id == run.id
  end

  test "capacity and list failures never become empty delivery or perform writes" do
    active()
    {:ok, run} = Trial.request(Ecto.UUID.generate())
    Process.put(:list_failure, true)
    assert {:error, :provider_unavailable} = Gmail.execute_trial(run.id)
    assert Repo.get!(TrialRun, run.id).state == "planned"
    Process.delete(:list_failure)
    Process.put(:mail, Map.new(1..21, &{"m#{&1}", ["Label_trial", "UNREAD"]}))
    assert {:error, :batch_capacity_exceeded} = Gmail.execute_trial(run.id)
    assert Process.get(:writes) == []
    assert Trial.summary([]).error == "batch_capacity_exceeded"
  end

  test "manual receipts do not consume future occurrence and delayed schedule coalesces cadence" do
    active()
    due = Trial.now() - 650
    run = Repo.insert!(%TrialRun{kind: "scheduled", due_at: due})
    Repo.get!(Trial, "primary") |> Ecto.Changeset.change(next_due: due) |> Repo.update!()
    assert {:ok, joined} = Trial.request(Ecto.UUID.generate())
    assert joined.id == run.id
    assert {:ok, _} = Gmail.execute_trial(run.id)
    next = Repo.get!(Trial, "primary").next_due
    assert next == due + 900
    [future] = Repo.all(from(r in TrialRun, where: r.state == "planned"))
    request = Ecto.UUID.generate()
    assert {:ok, manual} = Trial.request(request)
    assert manual.id != future.id
    assert {:ok, _} = Gmail.execute_trial(manual.id)
    assert {:ok, same} = Trial.request(request)
    assert same.id == manual.id
    assert Repo.get!(Trial, "primary").next_due == next
    assert Repo.get!(TrialRun, future.id).state == "planned"
    assert Trial.latest() == nil
  end

  test "new scheduled work cannot expand an unfinished manual run" do
    active()
    {:ok, manual} = Trial.request(Ecto.UUID.generate())
    later = Repo.insert!(%TrialRun{kind: "scheduled", due_at: Trial.now() + 1})
    later |> Ecto.Changeset.change(due_at: Trial.now()) |> Repo.update!()
    # Make ordering unambiguous rather than relying on UUID order within one second.
    manual |> Ecto.Changeset.change(due_at: Trial.now() - 1) |> Repo.update!()
    assert {:error, :operation_in_progress} = Gmail.execute_trial(later.id)
    assert Repo.get!(TrialRun, later.id).state == "planned"
  end

  test "stop is terminal, removes interception before restore, and fences persisted jobs", ctx do
    disabled_primary()
    assert {:ok, _} = Gmail.trial_start(ctx.session)
    label = Repo.get!(FilterExperiment, Trial.profile()).label_id
    Process.put(:mail, %{"m1" => [label, "UNREAD"]})
    {:ok, run} = Trial.request(Ecto.UUID.generate())
    Process.put(:stopping, true)

    assert {:ok, %{state: "stopped", instructions: nil, next_due: nil}} =
             Gmail.trial_stop(ctx.session)

    assert Process.get(:filters) == []
    assert "INBOX" in Process.get(:mail)["m1"]
    Req.Test.stub(__MODULE__, fn _ -> flunk("stopped job reached provider") end)
    assert {:error, :invalid_transition} = Gmail.execute_trial(run.id)
    assert {:error, :invalid_transition} = Gmail.trial_start(ctx.session)
  end

  test "trial stop preserves historical journals and never reads their deleted fixtures", ctx do
    prior = disabled_primary()
    specs = FilterProfile.specifications("primary", "owner@gmail.com", prior.nonce, "Label_old")

    prior =
      prior
      |> Ecto.Changeset.change(
        label_id: "Label_old",
        mail: %{"deleted_old" => "restored"},
        entries:
          Map.new(specs, fn {key, spec} ->
            {key, %{"spec" => spec, "id" => "old_#{key}", "state" => "deleted"}}
          end)
      )
      |> Repo.update!()

    assert {:ok, _} = Gmail.trial_start(ctx.session)
    Process.put(:mail, %{"m1" => ["Label_trial", "UNREAD"]})
    Process.put(:forbid_old, true)
    assert {:ok, %{state: "stopped"}} = Gmail.trial_stop(ctx.session)
    assert Repo.get!(FilterExperiment, "primary") == prior
    assert Process.get(:writes) == ["m1"]
    assert Process.get(:filters) == []
  end

  test "disconnect fences before cleanup, and reconnect cannot restore background authority",
       ctx do
    disabled_primary()
    assert {:ok, _} = Gmail.trial_start(ctx.session)
    {:ok, run} = Trial.request(Ecto.UUID.generate())
    assert {:ok, _} = Gmail.disconnect(ctx.session)
    assert Trial.summary([]).state == "stopped"
    Req.Test.stub(__MODULE__, fn _ -> flunk("disconnected job reached provider") end)
    assert {:error, :invalid_transition} = Gmail.execute_trial(run.id)
  end

  test "missing scope marks connected identity for reconnect and preserves pending delivery" do
    active()
    {:ok, run} = Trial.request(Ecto.UUID.generate())

    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(403)
      |> Req.Test.json(%{
        "error" => %{"details" => [%{"reason" => "ACCESS_TOKEN_SCOPE_INSUFFICIENT"}]}
      })
    end)

    assert {:error, :missing_scope} = Gmail.execute_trial(run.id)
    assert Repo.get!(Account, "primary").status == "reconnect_required"
    assert Repo.get!(TrialRun, run.id).state == "planned"
  end

  test "unattended refresh uses saved token lease and never browser credentials" do
    active()
    account = Repo.get!(Account, "primary")
    {:ok, tokens} = EmailSucks.Gmail.Vault.open(account.credentials, "gmail-tokens")

    account
    |> Ecto.Changeset.change(
      credentials: EmailSucks.Gmail.Vault.seal(Map.put(tokens, "expires_at", 0), "gmail-tokens"),
      session_digest: nil,
      session_expires_at: 0
    )
    |> Repo.update!()

    {:ok, run} = Trial.request(Ecto.UUID.generate())
    assert {:ok, _} = Gmail.execute_trial(run.id)
    assert Process.get(:refreshes) == 1
    assert Repo.get!(Account, "primary").refresh_until == 0
  end

  test "view preserves all frozen members and app-only reviews across empty windows", ctx do
    active()
    Process.put(:mail, %{"m1" => ["Label_trial", "UNREAD"], "m2" => ["Label_trial", "UNREAD"]})
    {:ok, run} = Trial.request(Ecto.UUID.generate())
    assert {:ok, _} = Gmail.execute_trial(run.id)
    assert {:ok, view} = TrialView.load(ctx.config, "test")
    assert view.run_id == run.id
    assert view.total == 1
    [item] = view.items
    assert length(item.contents) == 2
    writes = Process.get(:writes)

    assert {:ok, %{remaining: 0}} =
             TrialView.review(ctx.config, "test", run.id, view.revision, item.id, true)

    assert Process.get(:writes) == writes
    {:ok, empty} = Trial.request(Ecto.UUID.generate())
    assert {:ok, _} = Gmail.execute_trial(empty.id)
    assert {:ok, %{run_id: id, remaining: 0}} = TrialView.load(ctx.config, "test")
    assert id == run.id
    Process.put(:mail, Map.delete(Process.get(:mail), "m1"))
    assert {:ok, %{unavailable: 1}} = TrialView.load(ctx.config, "test")

    assert {:error, :stale} =
             TrialView.review(ctx.config, "test", run.id, view.revision, item.id, false)

    refute inspect(Repo.get!(TrialRun, run.id).entries) =~ "Preview"
  end

  defp active do
    Repo.insert!(%Trial{id: "primary", state: "active", next_due: Trial.now() + 300})
    nonce = String.duplicate("a", 32)
    specs = FilterProfile.specifications(Trial.profile(), "owner@gmail.com", nonce, "Label_trial")
    Process.put(:filters, [Map.put(specs["hold"], "id", "owned")])

    Repo.insert!(%FilterExperiment{
      id: Trial.profile(),
      state: "active",
      nonce: nonce,
      label_id: "Label_trial",
      baseline_ids: [],
      baseline_digest: digest(),
      entries:
        Map.new(specs, fn {key, spec} ->
          {key, %{"spec" => spec, "id" => "owned", "state" => "active"}}
        end)
    })
  end

  defp disabled_primary do
    Repo.insert!(%FilterExperiment{
      id: "primary",
      state: "disabled",
      nonce: String.duplicate("b", 32),
      baseline_ids: [],
      baseline_digest: digest()
    })
  end

  defp digest, do: :crypto.hash(:sha256, :erlang.term_to_binary([])) |> Base.encode16()
  defp jobs, do: Repo.all(from(j in Oban.Job, where: j.queue == "gmail_delivery"))

  defp provider(conn) do
    case {conn.method, conn.request_path} do
      {"POST", "/token"} ->
        Process.put(:refreshes, Process.get(:refreshes, 0) + 1)

        Req.Test.json(conn, %{
          "access_token" => "refreshed",
          "expires_in" => 3600,
          "token_type" => "Bearer",
          "scope" =>
            "https://www.googleapis.com/auth/gmail.modify https://www.googleapis.com/auth/gmail.settings.basic"
        })

      {"POST", "/revoke"} ->
        assert Trial.summary([]).state == "stopped"
        Req.Test.json(conn, %{})

      {"GET", "/gmail/v1/users/me/settings/filters"} ->
        Req.Test.json(conn, %{"filter" => Process.get(:filters)})

      {"POST", "/gmail/v1/users/me/settings/filters"} ->
        assert Trial.summary([]).state == "starting"
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        filter = Jason.decode!(body) |> Map.put("id", "owned")
        Process.put(:filters, [filter])
        Req.Test.json(conn, filter)

      {"DELETE", "/gmail/v1/users/me/settings/filters/owned"} ->
        assert Trial.summary([]).state == "stopping"
        Process.put(:filters, [])
        Req.Test.json(conn, %{})

      {"GET", "/gmail/v1/users/me/labels"} ->
        Req.Test.json(conn, %{"labels" => Process.get(:labels)})

      {"POST", "/gmail/v1/users/me/labels"} ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        label = Jason.decode!(body) |> Map.put("id", "Label_trial")
        Process.put(:labels, [label])
        Req.Test.json(conn, label)

      {"GET", "/gmail/v1/users/me/messages"} ->
        params = URI.decode_query(conn.query_string)

        if Process.get(:list_failure) do
          Plug.Conn.send_resp(conn, 503, "private")
        else
          ids =
            if params["labelIds"],
              do: for({id, labels} <- Process.get(:mail), params["labelIds"] in labels, do: id),
              else: []

          Req.Test.json(conn, %{"messages" => Enum.map(ids, &%{"id" => &1})})
        end

      {"GET", "/gmail/v1/users/me/messages/" <> id} ->
        if Process.get(:forbid_old), do: refute(id == "deleted_old")

        if labels = Process.get(:mail)[id] do
          Req.Test.json(conn, %{
            "id" => id,
            "threadId" => "thread",
            "labelIds" => labels,
            "snippet" => "Preview #{id}",
            "internalDate" => "1700000000000",
            "payload" => %{
              "headers" => [
                %{"name" => "From", "value" => "robertguss@gmail.com"},
                %{"name" => "To", "value" => "owner@gmail.com"},
                %{"name" => "Subject", "value" => FilterProfile.subject(Trial.profile())}
              ]
            }
          })
        else
          Plug.Conn.send_resp(conn, 404, "")
        end

      {"POST", "/gmail/v1/users/me/messages/" <> suffix} ->
        [id, "modify"] = String.split(suffix, "/")
        if Process.get(:stopping), do: assert(Process.get(:filters) == [])
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["addLabelIds"] == ["INBOX"]
        assert params["removeLabelIds"] == ["Label_trial"]

        labels =
          (Process.get(:mail)[id] ++ params["addLabelIds"])
          |> Enum.uniq()
          |> Enum.reject(&(&1 in params["removeLabelIds"]))

        Process.put(:mail, Map.put(Process.get(:mail), id, labels))
        Process.put(:writes, Process.get(:writes) ++ [id])

        if Process.delete(:late_arrival),
          do: Process.put(:mail, Map.put(Process.get(:mail), "late", ["Label_trial", "UNREAD"]))

        if Process.delete(:lose_modify),
          do: Plug.Conn.send_resp(conn, 503, "private"),
          else: Req.Test.json(conn, %{"id" => id})
    end
  end
end
