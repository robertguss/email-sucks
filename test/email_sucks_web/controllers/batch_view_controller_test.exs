defmodule EmailSucksWeb.BatchViewControllerTest do
  use EmailSucksWeb.ConnCase
  alias EmailSucks.{Gmail, Repo}
  alias EmailSucks.Gmail.Batch

  setup do
    old = Application.get_env(:email_sucks, :gmail)

    Application.put_env(:email_sucks, :gmail,
      client_id: "test",
      client_secret: "secret",
      allowed_email: "owner@gmail.com",
      redirect_uri: "http://localhost:4000/auth/google/callback",
      vault_key: String.duplicate("k", 64),
      http_options: [plug: {Req.Test, __MODULE__}]
    )

    on_exit(fn -> Application.put_env(:email_sucks, :gmail, old) end)

    {:ok, session} =
      Gmail.connect(%{subject: "subject", email: "owner@gmail.com"}, %{
        "access_token" => "private-access",
        "refresh_token" => "private-refresh",
        "scope" => "https://www.googleapis.com/auth/gmail.readonly",
        "expires_at" => System.system_time(:second) + 3600
      })

    Req.Test.stub(__MODULE__, &metadata/1)
    %{session: session}
  end

  test "authentication and CSRF protect review", %{conn: conn} do
    assert json_response(get(conn, "/gmail/batch-view"), 401)["error"] == "reconnect_required"

    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      conn
      |> put_private(:plug_skip_csrf_protection, false)
      |> post("/gmail/batch-view/review", %{revision: 0, item_id: "t1", reviewed: true})
    end

    assert redirected_to(get(conn, "/batch")) == "/"
  end

  test "exact saved membership groups and review persists independently of unread", ctx do
    source = seed()
    conn = login(ctx)
    data = json_response(get(conn, "/gmail/batch-view"), 200)
    assert data["total"] == 2
    assert data["remaining"] == 2
    assert Enum.map(data["items"], & &1["messages"]) |> Enum.sort() == [1, 2]
    item = Enum.find(data["items"], &(&1["messages"] == 2))
    assert Enum.map(item["contents"], & &1["id"]) == ["m1", "m2"]

    assert Enum.map(item["contents"], & &1["subject"]) == [
             "<b>Subject m1</b>",
             "<b>Subject m2</b>"
           ]

    assert Enum.map(item["contents"], & &1["preview"]) == [
             "<script>safe preview m1</script>",
             "<script>safe preview m2</script>"
           ]

    assert Enum.all?(item["contents"], &(&1["status"] == "available"))
    reviewed = review(conn, data["revision"], item["id"], true) |> json_response(200)
    assert reviewed["remaining"] == 1
    assert json_response(get(conn, "/gmail/batch-view"), 200)["remaining"] == 1
    assert json_response(review(conn, data["revision"], item["id"], false), 200)["remaining"] == 2
    assert Repo.get!(Batch, "primary") == source
  end

  test "unknown items and stale source revisions are rejected", ctx do
    source = seed()
    conn = login(ctx)
    data = json_response(get(conn, "/gmail/batch-view"), 200)
    assert json_response(review(conn, data["revision"], "foreign", true), 409)["error"] == "stale"
    source |> Ecto.Changeset.change(repeat_revision: 1) |> Repo.update!()

    assert json_response(review(conn, data["revision"], hd(data["items"])["id"], true), 409)[
             "error"
           ] == "stale"
  end

  test "gone trash and pending messages remain visible and cannot be reviewed", ctx do
    source = seed()
    conn = login(ctx)
    data = json_response(get(conn, "/gmail/batch-view"), 200)

    Req.Test.stub(__MODULE__, fn request ->
      case Path.basename(request.request_path) do
        "m1" -> send_resp(request, 404, "")
        "m2" -> metadata(request, ["TRASH", "UNREAD"])
        _ -> metadata(request)
      end
    end)

    unavailable = json_response(get(conn, "/gmail/batch-view"), 200)
    assert unavailable["total"] == 2
    assert unavailable["pending"] == 0
    assert unavailable["unavailable"] == 1
    item = Enum.find(unavailable["items"], &(&1["status"] == "unavailable"))
    assert json_response(review(conn, data["revision"], item["id"], true), 409)

    source
    |> Ecto.Changeset.change(
      entries: Map.put(source.entries, "m3", %{"state" => "release_pending", "error" => nil})
    )
    |> Repo.update!()

    pending = json_response(get(conn, "/gmail/batch-view"), 200)
    assert pending["state"] == "pending"
    assert pending["pending"] == 1
    assert pending["unavailable"] == 1
    assert pending["remaining"] == 0
  end

  test "reviewed group becomes unavailable after deletion without suggesting pending delivery",
       ctx do
    seed()
    conn = login(ctx)
    data = json_response(get(conn, "/gmail/batch-view"), 200)

    for item <- data["items"],
        do: json_response(review(conn, data["revision"], item["id"], true), 200)

    Req.Test.stub(__MODULE__, fn request ->
      if Path.basename(request.request_path) == "m1",
        do: send_resp(request, 404, ""),
        else: metadata(request)
    end)

    data = json_response(get(conn, "/gmail/batch-view"), 200)
    assert data["remaining"] == 0
    assert data["pending"] == 0
    assert data["unavailable"] == 1
    assert data["state"] == "pending"
    group = Enum.find(data["items"], &(&1["id"] == "t1"))
    assert group["reviewed"]
    assert Enum.map(group["contents"], & &1["status"]) == ["unavailable", "available"]
    assert hd(group["contents"])["subject"] == "Message unavailable"
  end

  test "thread drift keeps frozen grouping and rejects review", ctx do
    seed()
    conn = login(ctx)
    data = json_response(get(conn, "/gmail/batch-view"), 200)

    Req.Test.stub(__MODULE__, fn request ->
      response = metadata(request)
      body = Jason.decode!(response.resp_body) |> Map.put("threadId", "changed")
      %{response | resp_body: Jason.encode!(body)}
    end)

    drifted = json_response(get(conn, "/gmail/batch-view"), 200)
    assert Enum.map(drifted["items"], & &1["id"]) == Enum.map(data["items"], & &1["id"])
    assert drifted["unavailable"] == 2
    assert json_response(review(conn, data["revision"], "t1", true), 409)
  end

  test "provider outage is explicit and cannot mark review", ctx do
    seed()
    conn = login(ctx)
    data = json_response(get(conn, "/gmail/batch-view"), 200)
    Req.Test.stub(__MODULE__, &send_resp(&1, 503, "private-provider-error"))
    failure = review(conn, data["revision"], hd(data["items"])["id"], true)
    assert json_response(failure, 503) == %{"error" => "unavailable"}
    refute failure.resp_body =~ "private"
    Req.Test.stub(__MODULE__, &metadata/1)
    assert json_response(get(conn, "/gmail/batch-view"), 200)["remaining"] == 2
  end

  test "empty source returns empty and never discovers mail", ctx do
    Req.Test.stub(__MODULE__, fn _ -> flunk("empty batch called provider") end)
    assert json_response(get(login(ctx), "/gmail/batch-view"), 200)["state"] == "empty"
  end

  test "source membership changes invalidate the same revision and disconnect refuses reads",
       ctx do
    source = seed()
    conn = login(ctx)
    data = json_response(get(conn, "/gmail/batch-view"), 200)

    entries =
      source.entries
      |> Map.delete("m3")
      |> Map.put("m4", %{"state" => "released", "error" => nil})

    source |> Ecto.Changeset.change(entries: entries) |> Repo.update!()
    Req.Test.stub(__MODULE__, fn _ -> flunk("stale or disconnected request reached provider") end)
    assert json_response(review(conn, data["revision"], hd(data["items"])["id"], true), 409)

    Repo.get!(EmailSucks.Gmail.Account, "primary")
    |> Ecto.Changeset.change(disconnect_phase: "restoring")
    |> Repo.update!()

    assert json_response(get(conn, "/gmail/batch-view"), 409)
  end

  test "missing initial message retains every member without freezing partial grouping", ctx do
    seed()
    conn = login(ctx)

    Req.Test.stub(__MODULE__, fn request ->
      if Path.basename(request.request_path) == "m1",
        do: send_resp(request, 404, ""),
        else: metadata(request)
    end)

    data = json_response(get(conn, "/gmail/batch-view"), 200)
    assert data["revision"] == nil
    assert data["state"] == "pending"
    assert Enum.sum(Enum.map(data["items"], & &1["messages"])) == 3
    assert json_response(review(conn, nil, hd(data["items"])["id"], true), 409)
  end

  test "quota denial stays retryable but insufficient scope requires reconnect", ctx do
    seed()
    conn = login(ctx)

    Req.Test.stub(__MODULE__, fn request ->
      request
      |> put_status(403)
      |> Req.Test.json(%{"error" => %{"errors" => [%{"reason" => "rateLimitExceeded"}]}})
    end)

    assert json_response(get(conn, "/gmail/batch-view"), 503)
    assert Repo.get!(EmailSucks.Gmail.Account, "primary").status == "connected"

    Req.Test.stub(__MODULE__, fn request ->
      request
      |> put_status(403)
      |> Req.Test.json(%{
        "error" => %{"details" => [%{"reason" => "ACCESS_TOKEN_SCOPE_INSUFFICIENT"}]}
      })
    end)

    assert json_response(get(conn, "/gmail/batch-view"), 401)
    assert Repo.get!(EmailSucks.Gmail.Account, "primary").status == "reconnect_required"
  end

  defp login(%{conn: conn, session: session}),
    do: Plug.Test.init_test_session(conn, gmail_session: session)

  defp review(conn, revision, id, value),
    do:
      conn
      |> put_private(:plug_skip_csrf_protection, true)
      |> post("/gmail/batch-view/review", %{revision: revision, item_id: id, reviewed: value})

  defp seed do
    Repo.insert!(%Batch{
      id: "primary",
      state: "released",
      label_id: "Label_batch",
      entries: Map.new(~w(m1 m2 m3), &{&1, %{"state" => "released", "error" => nil}})
    })
  end

  defp metadata(request, labels \\ ["INBOX", "UNREAD"]) do
    assert request.method == "GET"
    id = Path.basename(request.request_path)
    assert id in ~w(m1 m2 m3)
    params = URI.decode_query(request.query_string)
    assert params["format"] == "metadata"

    Req.Test.json(request, %{
      "id" => id,
      "threadId" => if(id == "m3", do: "t2", else: "t1"),
      "labelIds" => labels,
      "snippet" => "<script>safe preview #{id}</script>",
      "internalDate" => "1700000000000",
      "payload" => %{
        "headers" => [
          %{"name" => "Subject", "value" => "<b>Subject #{id}</b>"},
          %{"name" => "From", "value" => "Sender <sender@example.com>"}
        ]
      }
    })
  end
end
