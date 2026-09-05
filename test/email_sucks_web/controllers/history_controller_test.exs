defmodule EmailSucksWeb.HistoryControllerTest do
  use EmailSucksWeb.ConnCase
  alias EmailSucks.{Gmail, Repo}
  alias EmailSucks.Gmail.{Account, Batch, Controlled, HistoryProbe}

  setup do
    old = Application.get_env(:email_sucks, :gmail)

    Application.put_env(:email_sucks, :gmail,
      client_id: "test",
      client_secret: "test-secret",
      allowed_email: "owner@gmail.com",
      redirect_uri: "http://localhost:4000/auth/google/callback",
      vault_key: String.duplicate("k", 64),
      http_options: [plug: {Req.Test, __MODULE__}]
    )

    on_exit(fn ->
      if old,
        do: Application.put_env(:email_sucks, :gmail, old),
        else: Application.delete_env(:email_sucks, :gmail)
    end)

    :ok
  end

  test "history controls require CSRF and an authenticated session", %{conn: conn} do
    Req.Test.stub(__MODULE__, fn _ -> flunk("anonymous history request reached Google") end)

    for action <- ["sync", "rescan"] do
      assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
        conn
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/gmail/history/" <> action)
      end

      result =
        conn |> put_private(:plug_skip_csrf_protection, true) |> post("/gmail/history/" <> action)

      assert redirected_to(result) == "/"
      assert get_resp_header(result, "cache-control") == ["no-store"]
    end

    public = get(conn, "/")
    assert Inertia.Testing.inertia_props(public).history == nil
  end

  test "fixed history forms ignore client membership and expose only public progress", %{
    conn: conn
  } do
    session = connect()
    save_fixtures()
    stub_reads()

    response =
      conn
      |> Plug.Test.init_test_session(gmail_session: session)
      |> put_private(:plug_skip_csrf_protection, true)
      |> post("/gmail/history/sync", %{
        "message_ids" => ["private-foreign"],
        "cursor" => "private-cursor",
        "action" => "hold"
      })

    assert redirected_to(response) == "/"
    assert HistoryProbe.summary().revision == 1

    assert Repo.get!(HistoryProbe, "primary").message_ids == [
             "private-m1",
             "private-m2",
             "private-m3",
             "private-m4"
           ]

    page = response |> recycle() |> get("/")
    props = Inertia.Testing.inertia_props(page)
    assert props.history.members == 4
    assert props.history.available == 4
    refute html_response(page, 200) =~ "private-"

    page
    |> recycle()
    |> put_private(:plug_skip_csrf_protection, true)
    |> post("/gmail/history/rescan")

    assert HistoryProbe.summary().revision == 2
    assert HistoryProbe.summary().mode == "rescan"
  end

  test "invalid actions cannot reach the provider", %{conn: conn} do
    session = connect()
    Req.Test.stub(__MODULE__, fn _ -> flunk("invalid action reached Google") end)

    conn
    |> Plug.Test.init_test_session(gmail_session: session)
    |> put_private(:plug_skip_csrf_protection, true)
    |> post("/gmail/history/hold")

    assert HistoryProbe.summary().state == "not_started"
  end

  test "pending disconnect refuses history without touching its journal", %{conn: conn} do
    session = connect()

    Repo.get!(Account, "primary")
    |> Ecto.Changeset.change(disconnect_phase: "restoring")
    |> Repo.update!()

    Req.Test.stub(__MODULE__, fn _ -> flunk("disconnect guard reached Google") end)

    conn
    |> Plug.Test.init_test_session(gmail_session: session)
    |> put_private(:plug_skip_csrf_protection, true)
    |> post("/gmail/history/sync")

    assert HistoryProbe.summary().state == "not_started"
  end

  test "expired access refreshes before history and revoked access stays visible", %{conn: conn} do
    session = connect(System.system_time(:second) - 1)
    save_fixtures()

    Req.Test.stub(__MODULE__, fn request ->
      if request.request_path =~ "token" do
        assert request.method == "POST"

        Req.Test.json(request, %{
          "access_token" => "fresh-access",
          "expires_in" => 3600,
          "token_type" => "Bearer"
        })
      else
        assert get_req_header(request, "authorization") == ["Bearer fresh-access"]
        read_response(request)
      end
    end)

    conn
    |> Plug.Test.init_test_session(gmail_session: session)
    |> put_private(:plug_skip_csrf_protection, true)
    |> post("/gmail/history/sync")

    assert HistoryProbe.summary().revision == 1
    Req.Test.stub(__MODULE__, &send_resp(&1, 401, "private-error"))

    conn
    |> Plug.Test.init_test_session(gmail_session: session)
    |> put_private(:plug_skip_csrf_protection, true)
    |> post("/gmail/history/sync")

    assert HistoryProbe.summary().revision == 1
    assert HistoryProbe.summary().error == "reconnect_required"
    assert Repo.get!(Account, "primary").status == "reconnect_required"
  end

  test "insufficient history scope requires reconnect and preserves the checkpoint", %{conn: conn} do
    session = connect()
    save_fixtures()
    stub_reads()

    conn
    |> Plug.Test.init_test_session(gmail_session: session)
    |> put_private(:plug_skip_csrf_protection, true)
    |> post("/gmail/history/sync")

    checkpoint = Repo.get!(HistoryProbe, "primary")

    Req.Test.stub(__MODULE__, fn request ->
      assert request.method == "GET"

      request
      |> put_status(403)
      |> Req.Test.json(%{
        "error" => %{
          "code" => 403,
          "status" => "PERMISSION_DENIED",
          "details" => [%{"reason" => "ACCESS_TOKEN_SCOPE_INSUFFICIENT"}]
        }
      })
    end)

    conn
    |> Plug.Test.init_test_session(gmail_session: session)
    |> put_private(:plug_skip_csrf_protection, true)
    |> post("/gmail/history/sync")

    assert HistoryProbe.summary().error == "missing_scope"
    assert Repo.get!(Account, "primary").status == "reconnect_required"
    current = Repo.get!(HistoryProbe, "primary")

    for field <- [:cursor, :observations, :message_ids, :revision, :checked_at, :mode] do
      assert Map.fetch!(current, field) == Map.fetch!(checkpoint, field)
    end
  end

  defp connect(expires_at \\ System.system_time(:second) + 3600) do
    {:ok, session} =
      Gmail.connect(%{subject: "subject", email: "owner@gmail.com"}, %{
        "access_token" => "private-access",
        "refresh_token" => "private-refresh",
        "scope" => "https://www.googleapis.com/auth/gmail.readonly",
        "expires_at" => expires_at
      })

    session
  end

  defp save_fixtures do
    Repo.insert!(%Controlled{
      id: "primary",
      state: "released",
      message_id: "private-m1",
      label_id: "Label_single"
    })

    Repo.insert!(%Batch{
      id: "primary",
      state: "released",
      label_id: "Label_batch",
      entries:
        Map.new(
          ~w(private-m2 private-m3 private-m4),
          &{&1, %{"state" => "released", "error" => nil}}
        )
    })
  end

  defp stub_reads, do: Req.Test.stub(__MODULE__, &read_response/1)

  defp read_response(request) do
    assert request.method == "GET"

    case Path.basename(request.request_path) do
      "profile" ->
        Req.Test.json(request, %{"historyId" => "100"})

      "history" ->
        Req.Test.json(request, %{"historyId" => "200"})

      id when id in ~w(private-m1 private-m2 private-m3 private-m4) ->
        Req.Test.json(request, %{"id" => id, "labelIds" => ["INBOX", "UNREAD"]})

      _ ->
        flunk("request outside fixed membership")
    end
  end
end
