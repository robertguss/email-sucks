defmodule EmailSucks.Gmail.FilterExperimentTest do
  use EmailSucks.DataCase
  alias EmailSucks.Gmail.FilterExperiment
  alias EmailSucks.Repo

  setup do
    Process.put(:filters, [
      %{
        "id" => "user",
        "criteria" => %{"from" => "private@example.com"},
        "action" => %{"addLabelIds" => ["TRASH"]}
      }
    ])

    Process.put(:writes, [])
    Process.put(:creates, 0)
    Process.put(:mail, %{})
    Req.Test.stub(__MODULE__, &provider/1)
    %{config: [allowed_email: "owner@gmail.com", http_options: [plug: {Req.Test, __MODULE__}]]}
  end

  test "activation saves bounded ownership, repeats cannot create another experiment", %{
    config: c
  } do
    assert {:ok, %{state: "active", filters: 2}} = FilterExperiment.run(c, "test", "activate")
    assert Process.get(:creates) == 2
    assert {:error, :invalid_transition} = FilterExperiment.run(c, "test", "activate")
    assert {:ok, %{state: "active"}} = FilterExperiment.run(c, "test", "inspect")
    assert Process.get(:writes) == []
    assert {:ok, %{state: "disabled"}} = FilterExperiment.run(c, "test", "disable")
    assert Enum.map(Process.get(:filters), & &1["id"]) == ["user"]
    assert {:error, :invalid_transition} = FilterExperiment.run(c, "test", "activate")
  end

  test "accepted creation with lost response is reconciled without duplicate create", %{config: c} do
    Process.put(:lose_create, true)
    assert {:error, :provider_unavailable} = FilterExperiment.run(c, "test", "activate")
    assert %{state: "preparing", pending: 2} = FilterExperiment.summary()
    assert {:ok, %{state: "active"}} = FilterExperiment.run(c, "test", "recover")
    assert Process.get(:creates) == 2
  end

  test "unconfirmed creation is never blindly retried or declared safely disabled", %{config: c} do
    Process.put(:unknown_create, true)
    assert {:error, :provider_unavailable} = FilterExperiment.run(c, "test", "activate")
    assert {:error, :filter_creation_uncertain} = FilterExperiment.run(c, "test", "recover")
    assert {:error, :filter_creation_uncertain} = FilterExperiment.run(c, "test", "disable")
    assert Process.get(:creates) == 1
  end

  test "changed owned filter blocks cleanup and never deletes user filters", %{config: c} do
    assert {:ok, _} = FilterExperiment.run(c, "test", "activate")
    [user, first | rest] = Process.get(:filters)

    Process.put(:filters, [
      user,
      put_in(first, ["criteria", "from"], "changed@example.com") | rest
    ])

    assert {:error, :filter_drift} = FilterExperiment.run(c, "test", "disable")
    assert Process.get(:writes) == []
    assert Enum.any?(Process.get(:filters), &(&1["id"] == "user"))
  end

  test "cleanup removes filters before restoring eligible mail and leaves Trash untouched", %{
    config: c
  } do
    assert {:ok, _} = FilterExperiment.run(c, "test", "activate")

    Process.put(:mail, %{
      "m1" => ["Label_lab", "UNREAD", "STARRED"],
      "m2" => ["Label_lab", "TRASH", "UNREAD"]
    })

    assert :ok = FilterExperiment.restore_for_disconnect(c, "test")
    assert %{state: "disabled", restored: 1, excluded: 1} = FilterExperiment.summary()
    assert Process.get(:mail)["m1"] |> Enum.sort() == Enum.sort(["INBOX", "UNREAD", "STARRED"])
    assert Process.get(:mail)["m2"] == ["Label_lab", "TRASH", "UNREAD"]
    assert Process.get(:writes) == ["m1"]
    assert :ok = FilterExperiment.restore_for_disconnect(c, "test")
    assert Process.get(:writes) == ["m1"]
  end

  test "lost delete response recovers absence without repeating the delete", %{config: c} do
    assert {:ok, _} = FilterExperiment.run(c, "test", "activate")
    Process.put(:lose_delete, true)
    assert {:error, :provider_unavailable} = FilterExperiment.run(c, "test", "disable")
    assert %{state: "disabling"} = FilterExperiment.summary()
    assert {:ok, %{state: "disabled"}} = FilterExperiment.run(c, "test", "recover")
    assert Process.get(:deletes) == 2
  end

  test "cleanup detects a later visible held message and resumes without repeating writes", %{
    config: c
  } do
    assert {:ok, _} = FilterExperiment.run(c, "test", "activate")
    Process.put(:mail, %{"m1" => ["Label_lab", "UNREAD"]})
    Process.put(:late_arrival, true)
    assert {:error, :filter_cleanup_pending} = FilterExperiment.run(c, "test", "disable")
    assert {:ok, %{state: "disabled", restored: 2}} = FilterExperiment.run(c, "test", "recover")
    assert Process.get(:writes) == ["m1", "late"]
  end

  test "provider drift in original filters is visible before activation", %{config: c} do
    Process.put(:preexisting, true)
    assert {:error, :fixture_mismatch} = FilterExperiment.run(c, "test", "activate")
    assert %{state: "not_started"} = FilterExperiment.summary()
    assert Process.get(:creates) == 0
  end

  test "disconnect retains access until interrupted filter cleanup completes", %{config: c} do
    old = Application.get_env(:email_sucks, :gmail)

    Application.put_env(
      :email_sucks,
      :gmail,
      Keyword.merge(c,
        client_id: "test",
        client_secret: "secret",
        redirect_uri: "http://localhost/callback",
        vault_key: String.duplicate("k", 64)
      )
    )

    on_exit(fn -> Application.put_env(:email_sucks, :gmail, old) end)

    tokens = %{
      "access_token" => "test",
      "refresh_token" => "refresh",
      "expires_at" => System.system_time(:second) + 3600,
      "scope" => "https://www.googleapis.com/auth/gmail.modify"
    }

    identity = %{subject: "subject", email: "owner@gmail.com"}
    {:ok, session} = EmailSucks.Gmail.connect(identity, tokens)
    assert {:ok, _} = FilterExperiment.run(c, "test", "activate")
    Process.put(:mail, %{"m1" => ["Label_lab", "UNREAD"]})
    assert {:error, :filter_settings_required} = EmailSucks.Gmail.disconnect(session)
    assert EmailSucks.Gmail.account(session).disconnect_phase == "restoring"
    assert Process.get(:deletes, 0) == 0
    assert Process.get(:writes) == []
    refute Process.get(:revoked)

    tokens =
      Map.update!(
        tokens,
        "scope",
        &(&1 <> " https://www.googleapis.com/auth/gmail.settings.basic")
      )

    {:ok, session} = EmailSucks.Gmail.connect(identity, tokens)
    Process.put(:lose_delete, true)
    assert {:error, :provider_unavailable} = EmailSucks.Gmail.disconnect(session)
    assert EmailSucks.Gmail.account(session).disconnect_phase == "restoring"
    refute Process.get(:revoked)
    assert Process.get(:writes) == []
    assert {:ok, _} = EmailSucks.Gmail.disconnect(session)
    assert Process.get(:revoked)
    assert Process.get(:writes) == ["m1"]
    assert EmailSucks.Gmail.account(session) == nil
  end

  test "changed original filters are reported without preventing safe cleanup", %{config: c} do
    assert {:ok, _} = FilterExperiment.run(c, "test", "activate")
    Process.put(:filters, Enum.reject(Process.get(:filters), &(&1["id"] == "user")))
    assert {:error, :filter_baseline_changed} = FilterExperiment.run(c, "test", "inspect")

    assert {:ok, %{state: "disabled", baseline_changed: true}} =
             FilterExperiment.run(c, "test", "disable")

    assert Process.get(:filters) == []

    assert {:ok, %{state: "disabled", baseline_changed: true}} =
             FilterExperiment.run(c, "test", "inspect")

    assert :ok = FilterExperiment.restore_for_disconnect(c, "test")
  end

  test "pending inspection refuses the transition without falsely reporting drift", %{config: c} do
    Process.put(:lose_create, true)
    assert {:error, :provider_unavailable} = FilterExperiment.run(c, "test", "activate")
    assert {:error, :invalid_transition} = FilterExperiment.run(c, "test", "inspect")
    assert {:ok, _} = FilterExperiment.run(c, "test", "recover")
    Process.put(:lose_delete, true)
    assert {:error, :provider_unavailable} = FilterExperiment.run(c, "test", "disable")
    assert {:error, :invalid_transition} = FilterExperiment.run(c, "test", "inspect")
    assert {:ok, _} = FilterExperiment.run(c, "test", "recover")
  end

  test "rejected stale actions cannot erase a known provider failure", %{config: c} do
    Process.put(:lose_create, true)
    assert {:error, :provider_unavailable} = FilterExperiment.run(c, "test", "activate")
    assert {:error, :invalid_transition} = FilterExperiment.run(c, "test", "inspect")
    assert FilterExperiment.summary().error == "provider_unavailable"
    assert {:ok, _} = FilterExperiment.run(c, "test", "recover")
    [user, first | rest] = Process.get(:filters)

    Process.put(:filters, [
      user,
      put_in(first, ["criteria", "from"], "changed@example.com") | rest
    ])

    assert {:error, :filter_drift} = FilterExperiment.run(c, "test", "inspect")
    assert {:error, :invalid_transition} = FilterExperiment.run(c, "test", "activate")
    assert FilterExperiment.summary().error == "filter_drift"
    assert :gmail_operation_failed in EmailSucks.OperationalHealth.check().failures
  end

  test "ordinary profile is gated, isolated and recovers a lost accepted Hold create", %{
    config: c
  } do
    assert {:error, :invalid_transition} =
             FilterExperiment.run(c, "test", "activate", "arrival-primary-v1")

    assert {:ok, _} = FilterExperiment.run(c, "test", "activate")
    assert FilterExperiment.recovery_required?()

    assert {:error, :invalid_transition} =
             FilterExperiment.run(c, "test", "activate", "arrival-primary-v1")

    Process.put(:mail, %{"m2" => ["Label_lab", "TRASH", "UNREAD"]})
    assert {:ok, _} = FilterExperiment.run(c, "test", "disable")
    primary = Repo.get!(FilterExperiment, "primary")
    refute FilterExperiment.recovery_required?()
    Process.put(:lose_create, true)

    assert {:error, :provider_unavailable} =
             FilterExperiment.run(c, "test", "activate", "arrival-primary-v1")

    assert %{state: "preparing", pending: 1} = FilterExperiment.summary("arrival-primary-v1")

    assert {:ok, %{state: "active", filters: 1}} =
             FilterExperiment.run(c, "test", "recover", "arrival-primary-v1")

    assert Process.get(:creates) == 3
    arrival = Repo.get!(FilterExperiment, "arrival-primary-v1")
    assert Map.keys(arrival.entries) == ["hold"]
    assert arrival.nonce != primary.nonce
    assert arrival.label_id != primary.label_id
    assert primary == Repo.get!(FilterExperiment, "primary")

    Process.put(
      :mail,
      Map.put(Process.get(:mail), "ordinary", [arrival.label_id, "UNREAD", "STARRED"])
    )

    Process.put(:subjects, %{"ordinary" => "phase0-filter-arrival-001"})
    assert :ok = FilterExperiment.restore_for_disconnect(c, "test")
    assert FilterExperiment.summary("arrival-primary-v1").restored == 1
    assert Process.get(:mail)["m2"] == ["Label_lab", "TRASH", "UNREAD"]
    assert Enum.sort(Process.get(:mail)["ordinary"]) == Enum.sort(["INBOX", "UNREAD", "STARRED"])
    assert Process.get(:writes) == ["ordinary"]
    assert primary == Repo.get!(FilterExperiment, "primary")
    refute FilterExperiment.recovery_required?()

    assert Map.keys(FilterExperiment.summaries()) |> Enum.sort() == [
             "arrival-primary-v1",
             "primary"
           ]
  end

  test "unknown profiles fail closed and disconnect refuses unknown durable rows", %{config: c} do
    Req.Test.stub(__MODULE__, fn _ -> flunk("unknown profile must not call provider") end)

    assert {:error, :invalid_transition} =
             FilterExperiment.run(c, "test", "activate", "arbitrary")

    assert {:error, :invalid_transition} = FilterExperiment.summary("arbitrary")
    assert FilterExperiment.summaries()["arrival-primary-v1"].state == "not_started"

    Repo.insert!(%FilterExperiment{
      id: "unknown",
      state: "disabled",
      nonce: "unknown",
      baseline_ids: [],
      baseline_digest: "unknown"
    })

    assert FilterExperiment.recovery_required?()
    assert {:error, :invalid_transition} = FilterExperiment.restore_for_disconnect(c, "test")
    assert {:error, :invalid_transition} = FilterExperiment.run(c, "test", "activate")
  end

  test "persisted cross-profile specifications are rejected before deletion", %{config: c} do
    assert {:ok, _} = FilterExperiment.run(c, "test", "activate")
    row = Repo.get!(FilterExperiment, "primary")

    entries =
      put_in(row.entries, ["hold", "spec", "criteria", "subject"], "phase0-filter-arrival-001")

    row |> Ecto.Changeset.change(entries: entries) |> Repo.update!()

    Req.Test.stub(__MODULE__, fn _ ->
      flunk("mismatched durable profile must not call provider")
    end)

    assert {:error, :filter_drift} = FilterExperiment.run(c, "test", "disable")
  end

  test "ordinary cleanup retries late visibility without rewriting confirmed mail", %{config: c} do
    assert {:ok, _} = FilterExperiment.run(c, "test", "activate")
    assert {:ok, _} = FilterExperiment.run(c, "test", "disable")
    assert {:ok, _} = FilterExperiment.run(c, "test", "activate", "arrival-primary-v1")

    Process.put(:subjects, %{
      "ordinary" => "phase0-filter-arrival-001",
      "late" => "phase0-filter-arrival-001"
    })

    Process.put(:mail, %{"ordinary" => ["Label_arrival", "UNREAD"]})
    Process.put(:late_arrival, "Label_arrival")

    assert {:error, :filter_cleanup_pending} =
             FilterExperiment.run(c, "test", "disable", "arrival-primary-v1")

    assert {:ok, %{state: "disabled", restored: 2}} =
             FilterExperiment.run(c, "test", "recover", "arrival-primary-v1")

    assert Process.get(:writes) == ["ordinary", "late"]
  end

  test "ordinary ambiguous creation with no matching provider filter cannot be blindly retried",
       %{config: c} do
    assert {:ok, _} = FilterExperiment.run(c, "test", "activate")
    assert {:ok, _} = FilterExperiment.run(c, "test", "disable")
    Process.put(:unknown_create, true)

    assert {:error, :provider_unavailable} =
             FilterExperiment.run(c, "test", "activate", "arrival-primary-v1")

    assert {:error, :filter_creation_uncertain} =
             FilterExperiment.run(c, "test", "recover", "arrival-primary-v1")

    assert {:error, :filter_creation_uncertain} =
             FilterExperiment.run(c, "test", "disable", "arrival-primary-v1")

    assert Process.get(:creates) == 3
  end

  test "disconnect stops arrival interception before a historical primary message failure", %{
    config: c
  } do
    old = Application.get_env(:email_sucks, :gmail)

    Application.put_env(
      :email_sucks,
      :gmail,
      Keyword.merge(c,
        client_id: "test",
        client_secret: "secret",
        redirect_uri: "http://localhost/callback",
        vault_key: String.duplicate("k", 64)
      )
    )

    on_exit(fn -> Application.put_env(:email_sucks, :gmail, old) end)

    tokens = %{
      "access_token" => "test",
      "refresh_token" => "refresh",
      "expires_at" => System.system_time(:second) + 3600,
      "scope" =>
        "https://www.googleapis.com/auth/gmail.modify https://www.googleapis.com/auth/gmail.settings.basic"
    }

    {:ok, session} =
      EmailSucks.Gmail.connect(%{subject: "subject", email: "owner@gmail.com"}, tokens)

    assert {:ok, _} = FilterExperiment.run(c, "test", "activate")
    Process.put(:mail, %{"historical" => ["Label_lab", "TRASH", "UNREAD"]})
    assert {:ok, _} = FilterExperiment.run(c, "test", "disable")
    assert {:ok, _} = FilterExperiment.run(c, "test", "activate", "arrival-primary-v1")
    Process.put(:mail, %{"ordinary" => ["Label_arrival", "UNREAD", "STARRED"]})
    Process.put(:subjects, %{"ordinary" => "phase0-filter-arrival-001"})
    Process.put(:missing_message, "historical")
    assert {:error, :not_found} = EmailSucks.Gmail.disconnect(session)
    assert Enum.map(Process.get(:filters), & &1["id"]) == ["user"]
    assert FilterExperiment.summary().error == "not_found"
    assert EmailSucks.Gmail.account(session).disconnect_phase == "restoring"
    assert EmailSucks.Gmail.account(session).credentials != ""
    refute Process.get(:revoked)
    assert Process.get(:writes) == ["ordinary"]
    assert Enum.sort(Process.get(:mail)["ordinary"]) == Enum.sort(["INBOX", "UNREAD", "STARRED"])
    deletes = Process.get(:deletes)
    assert {:error, :not_found} = EmailSucks.Gmail.disconnect(session)
    assert Process.get(:deletes) == deletes
    assert Process.get(:writes) == ["ordinary"]
    refute Process.get(:revoked)
  end

  defp provider(conn) do
    case {conn.method, conn.request_path} do
      {"POST", "/revoke"} ->
        assert %{state: "disabled", restored: 1} = FilterExperiment.summary()
        assert Enum.map(Process.get(:filters), & &1["id"]) == ["user"]
        assert "INBOX" in Process.get(:mail)["m1"]
        Process.put(:revoked, true)
        Req.Test.json(conn, %{})

      {"GET", "/gmail/v1/users/me/settings/filters"} ->
        Req.Test.json(conn, %{"filter" => Process.get(:filters)})

      {"POST", "/gmail/v1/users/me/settings/filters"} ->
        assert Enum.any?(Repo.all(FilterExperiment), fn row ->
                 Enum.any?(row.entries, fn {_, e} -> e["state"] == "creating" end)
               end)

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        spec = Jason.decode!(body)
        n = Process.get(:creates) + 1
        Process.put(:creates, n)
        f = Map.put(spec, "id", "owned#{n}")

        unless Process.get(:unknown_create),
          do: Process.put(:filters, Process.get(:filters) ++ [f])

        if Process.delete(:lose_create) || Process.get(:unknown_create),
          do: Plug.Conn.send_resp(conn, 503, "private"),
          else: Req.Test.json(conn, f)

      {"DELETE", "/gmail/v1/users/me/settings/filters/" <> id} ->
        refute id == "user"
        Process.put(:deletes, Process.get(:deletes, 0) + 1)
        Process.put(:filters, Enum.reject(Process.get(:filters), &(&1["id"] == id)))

        if Process.delete(:lose_delete),
          do: Plug.Conn.send_resp(conn, 503, "private"),
          else: Req.Test.json(conn, %{})

      {"GET", "/gmail/v1/users/me/labels"} ->
        Req.Test.json(conn, %{"labels" => Process.get(:lab_labels, [])})

      {"POST", "/gmail/v1/users/me/labels"} ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        id = if Process.get(:lab_labels, []) == [], do: "Label_lab", else: "Label_arrival"
        label = Map.put(Jason.decode!(body), "id", id)
        Process.put(:lab_labels, Process.get(:lab_labels, []) ++ [label])
        Req.Test.json(conn, label)

      {"GET", "/gmail/v1/users/me/messages"} ->
        params = URI.decode_query(conn.query_string)

        ids =
          if params["labelIds"],
            do: for({id, labels} <- Process.get(:mail), params["labelIds"] in labels, do: id),
            else: if(Process.get(:preexisting), do: ["old"], else: [])

        Req.Test.json(conn, %{"messages" => Enum.map(ids, &%{"id" => &1})})

      {"GET", "/gmail/v1/users/me/messages/" <> id} ->
        if Process.get(:missing_message) == id do
          assert Enum.map(Process.get(:filters), & &1["id"]) == ["user"]
          Plug.Conn.send_resp(conn, 404, "")
        else
          Req.Test.json(conn, %{
            "id" => id,
            "labelIds" => Process.get(:mail)[id],
            "payload" => %{
              "headers" => [
                %{"name" => "From", "value" => "robertguss@gmail.com"},
                %{"name" => "To", "value" => "owner@gmail.com"},
                %{
                  "name" => "Subject",
                  "value" => Map.get(Process.get(:subjects, %{}), id, "phase0-filter-trash-001")
                }
              ]
            }
          })
        end

      {"POST", "/gmail/v1/users/me/messages/" <> suffix} ->
        [id, "modify"] = String.split(suffix, "/")
        assert Enum.map(Process.get(:filters), & &1["id"]) == ["user"]
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        labels =
          (Process.get(:mail)[id] ++ params["addLabelIds"])
          |> Enum.uniq()
          |> Enum.reject(&(&1 in params["removeLabelIds"]))

        Process.put(:mail, Map.put(Process.get(:mail), id, labels))

        if late = Process.delete(:late_arrival) do
          label = if is_binary(late), do: late, else: "Label_lab"
          Process.put(:mail, Map.put(Process.get(:mail), "late", [label, "UNREAD"]))
        end

        Process.put(:writes, Process.get(:writes) ++ [id])
        Req.Test.json(conn, %{"id" => id})
    end
  end
end
