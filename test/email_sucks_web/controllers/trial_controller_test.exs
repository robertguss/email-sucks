defmodule EmailSucksWeb.TrialControllerTest do
  use EmailSucksWeb.ConnCase
  alias EmailSucks.{Gmail, Repo}
  alias EmailSucks.Gmail.{Account, Trial}

  setup do
    old = Application.get_env(:email_sucks, :gmail)

    Application.put_env(:email_sucks, :gmail,
      allowed_email: "owner@gmail.com",
      vault_key: String.duplicate("k", 64),
      http_options: [plug: {Req.Test, __MODULE__}]
    )

    on_exit(fn -> Application.put_env(:email_sucks, :gmail, old) end)

    {:ok, session} =
      Gmail.connect(%{subject: "subject", email: "owner@gmail.com"}, %{
        "access_token" => "test",
        "refresh_token" => "refresh",
        "expires_at" => Trial.now() + 3600
      })

    Req.Test.stub(__MODULE__, fn _ -> flunk("summary/auth tests must not touch Gmail") end)
    %{session: session}
  end

  test "every trial endpoint requires browser authentication", %{conn: conn} do
    for path <- ["/gmail/trial", "/gmail/trial/view"],
        do: assert(json_response(get(conn, path), 401))

    for action <- ["start", "check-now", "stop", "review"] do
      assert json_response(
               conn
               |> put_private(:plug_skip_csrf_protection, true)
               |> post("/gmail/trial/" <> action, %{}),
               401
             )
    end
  end

  test "all mutation endpoints require CSRF", %{conn: conn, session: session} do
    for action <- ["start", "check-now", "stop", "review"] do
      assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
        conn
        |> Plug.Test.init_test_session(gmail_session: session)
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/gmail/trial/" <> action, %{})
      end
    end
  end

  test "summary is private database-only state and arbitrary criteria cannot start without settings grant",
       %{conn: conn, session: session} do
    conn = Plug.Test.init_test_session(conn, gmail_session: session)
    response = get(conn, "/gmail/trial")
    assert get_resp_header(response, "cache-control") == ["no-store"]

    assert json_response(response, 200) == %{
             "state" => "not_started",
             "next_due" => nil,
             "error" => nil,
             "instructions" => nil,
             "latest_run_id" => nil,
             "running" => false,
             "latest_run_state" => nil
           }

    assert json_response(
             conn
             |> put_private(:plug_skip_csrf_protection, true)
             |> post("/gmail/trial/start", %{subject: "arbitrary"}),
             401
           )

    assert Repo.get(Trial, "primary") == nil
  end

  test "manual receipt rejects arbitrary identities and disconnect blocks enqueue", %{
    conn: conn,
    session: session
  } do
    Repo.insert!(%Trial{id: "primary", state: "active", next_due: Trial.now() + 300})

    conn =
      conn
      |> Plug.Test.init_test_session(gmail_session: session)
      |> put_private(:plug_skip_csrf_protection, true)

    assert json_response(post(conn, "/gmail/trial/check-now", %{request_id: "bad"}), 409)

    assert json_response(
             post(conn, "/gmail/trial/check-now", %{request_id: Ecto.UUID.generate()}),
             200
           )["running"]

    Repo.get!(Account, "primary")
    |> Ecto.Changeset.change(disconnect_phase: "restoring")
    |> Repo.update!()

    assert json_response(
             post(conn, "/gmail/trial/check-now", %{request_id: Ecto.UUID.generate()}),
             409
           )
  end
end
