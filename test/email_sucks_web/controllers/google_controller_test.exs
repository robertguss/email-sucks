defmodule EmailSucksWeb.GoogleControllerTest do
  use EmailSucksWeb.ConnCase
  alias EmailSucks.Gmail

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

  test "start requires CSRF protection", %{conn: conn} do
    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      conn |> put_private(:plug_skip_csrf_protection, false) |> post("/auth/google")
    end
  end

  test "authorization redirect stores only an opaque flow identifier", %{conn: conn} do
    conn = conn |> bypass_csrf() |> post("/auth/google")
    assert redirected_to(conn) =~ "https://accounts.google.com/o/oauth2/v2/auth?"
    assert get_session(conn) |> Map.keys() == ["gmail_flow"]
    assert byte_size(get_session(conn, "gmail_flow")) == 43
    assert get_resp_header(conn, "cache-control") == ["no-store"]
    assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]
  end

  test "callback without the initiating browser fails without disclosing query values", %{
    conn: conn
  } do
    conn = get(conn, "/auth/google/callback?code=private-code&state=private-state")
    assert redirected_to(conn) == "/"
    conn = conn |> recycle() |> get("/")
    body = html_response(conn, 200)
    refute body =~ "private-code"
    refute body =~ "private-state"
    refute Inertia.Testing.inertia_props(conn).gmail_connected
  end

  test "connection and account identity are visible only to authenticated browser", %{conn: conn} do
    {:ok, session} =
      Gmail.connect(%{subject: "subject", email: "owner@gmail.com"}, %{
        "access_token" => "private-access",
        "refresh_token" => "private-refresh",
        "expires_at" => System.system_time(:second) + 3600
      })

    public = get(conn, "/")
    refute html_response(public, 200) =~ "owner@gmail.com"
    conn = conn |> Plug.Test.init_test_session(gmail_session: session) |> get("/")
    props = Inertia.Testing.inertia_props(conn)
    assert props.gmail_connected
    assert props.gmail_email == "owner@gmail.com"
    refute html_response(conn, 200) =~ "private-access"
    refute html_response(conn, 200) =~ "private-refresh"
    refute html_response(conn, 200) =~ session
    conn = conn |> recycle() |> bypass_csrf() |> post("/auth/logout")
    assert redirected_to(conn) == "/"
    assert Gmail.account(session) == nil
  end

  test "unauthenticated profile checks are refused", %{conn: conn} do
    conn = conn |> bypass_csrf() |> post("/gmail/check")
    assert redirected_to(conn) == "/"
    assert get_session(conn, "gmail_session") == nil
  end

  test "a browser completes signed OAuth, then cannot replay the callback", %{conn: conn} do
    initial = get(conn, "/")
    csrf = Inertia.Testing.inertia_props(initial).csrf_token

    started =
      initial
      |> recycle()
      |> put_private(:plug_skip_csrf_protection, false)
      |> post("/auth/google", %{"_csrf_token" => csrf})

    params = started |> redirected_to() |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
    key = :public_key.generate_key({:rsa, 2048, 65537})
    pem = :public_key.pem_encode([:public_key.pem_entry_encode(:RSAPrivateKey, key)])
    encode = fn n -> n |> :binary.encode_unsigned() |> Base.url_encode64(padding: false) end

    jwk = %{
      "kty" => "RSA",
      "kid" => "test",
      "n" => encode.(elem(key, 2)),
      "e" => encode.(elem(key, 3))
    }

    claims = %{
      "iss" => "https://accounts.google.com",
      "aud" => "test",
      "sub" => "subject",
      "email" => "owner@gmail.com",
      "email_verified" => true,
      "nonce" => params["nonce"],
      "exp" => System.system_time(:second) + 3600,
      "iat" => System.system_time(:second)
    }

    {:ok, jwt} =
      Assent.JWTAdapter.AssentJWT.sign(claims, "RS256", pem,
        json_library: Jason,
        private_key_id: "test"
      )

    Req.Test.stub(__MODULE__, fn conn ->
      case conn.request_path do
        "/token" ->
          Req.Test.json(conn, %{
            "id_token" => jwt,
            "access_token" => "private-access",
            "refresh_token" => "private-refresh",
            "expires_in" => 3600,
            "token_type" => "Bearer",
            "scope" => "openid email https://www.googleapis.com/auth/gmail.modify"
          })

        "/oauth2/v3/certs" ->
          Req.Test.json(conn, %{"keys" => [jwk]})
      end
    end)

    callback =
      "/auth/google/callback?" <>
        URI.encode_query(%{"code" => "private-code", "state" => params["state"]})

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        connected = started |> recycle() |> get(callback)
        assert redirected_to(connected) == "/"
        session = get_session(connected, :gmail_session)
        assert Gmail.account(session)
        assert get_session(connected, :gmail_flow) == nil
        replayed = connected |> recycle() |> get(callback)
        assert redirected_to(replayed) == "/"
        assert get_session(replayed, :gmail_session) == session
        assert replayed.assigns.flash["info"] =~ "could not be completed"
      end)

    for value <- ["private-code", "private-access", "private-refresh", jwt],
        do: refute(log =~ value)
  end

  test "message listing requires a current browser session and never caches results", %{
    conn: conn
  } do
    denied = get(conn, "/gmail/messages")
    assert json_response(denied, 401) == %{"error" => "reconnect_required"}

    {:ok, session} =
      Gmail.connect(%{subject: "subject", email: "owner@gmail.com"}, %{
        "access_token" => "private-access",
        "refresh_token" => "private-refresh",
        "expires_at" => System.system_time(:second) + 3600
      })

    Req.Test.stub(__MODULE__, fn conn -> Req.Test.json(conn, %{"messages" => []}) end)
    listed = conn |> Plug.Test.init_test_session(gmail_session: session) |> get("/gmail/messages")
    assert json_response(listed, 200) == %{"messages" => []}
    assert get_resp_header(listed, "cache-control") == ["no-store"]
    Req.Test.stub(__MODULE__, fn conn -> Plug.Conn.send_resp(conn, 401, "private error") end)

    revoked =
      conn |> Plug.Test.init_test_session(gmail_session: session) |> get("/gmail/messages")

    assert json_response(revoked, 401) == %{"error" => "reconnect_required"}
    assert Gmail.account(session).status == "reconnect_required"
  end

  test "authenticated recovery exposes verified state without exposing provider IDs", %{
    conn: conn
  } do
    {:ok, session} =
      Gmail.connect(%{subject: "subject", email: "owner@gmail.com"}, %{
        "access_token" => "private-access",
        "refresh_token" => "private-refresh",
        "expires_at" => System.system_time(:second) + 3600
      })

    EmailSucks.Repo.insert!(%EmailSucks.Gmail.Controlled{
      id: "primary",
      message_id: "private_message",
      label_id: "Label_private",
      state: "hold_pending"
    })

    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert String.ends_with?(conn.request_path, "/private_message")
      Req.Test.json(conn, %{"id" => "private_message", "labelIds" => ["Label_private", "UNREAD"]})
    end)

    result =
      conn
      |> Plug.Test.init_test_session(gmail_session: session)
      |> bypass_csrf()
      |> post("/gmail/controlled/recover", %{"message_id" => "arbitrary"})

    assert result.assigns.flash["info"] =~ "held; verified"
    home = result |> recycle() |> get("/")
    assert Inertia.Testing.inertia_props(home).controlled.state == "held"
    refute html_response(home, 200) =~ "private_message"
    refute html_response(home, 200) =~ "Label_private"
  end

  test "repeat form passes its revision and uses only the saved message", %{conn: conn} do
    {:ok, session} =
      Gmail.connect(%{subject: "subject", email: "owner@gmail.com"}, %{
        "access_token" => "private-access",
        "refresh_token" => "private-refresh",
        "expires_at" => System.system_time(:second) + 3600
      })

    EmailSucks.Repo.insert!(%EmailSucks.Gmail.Controlled{
      id: "primary",
      message_id: "saved",
      label_id: "Label_saved",
      state: "released"
    })

    Process.put(:repeat_labels, ["INBOX", "UNREAD"])

    Req.Test.stub(__MODULE__, fn request ->
      assert request.request_path in [
               "/gmail/v1/users/me/messages/saved",
               "/gmail/v1/users/me/messages/saved/modify"
             ]

      if request.method == "POST", do: Process.put(:repeat_labels, ["Label_saved", "UNREAD"])
      Req.Test.json(request, %{"id" => "saved", "labelIds" => Process.get(:repeat_labels)})
    end)

    result =
      conn
      |> Plug.Test.init_test_session(gmail_session: session)
      |> bypass_csrf()
      |> post("/gmail/controlled/repeat", %{"repeat_revision" => "0", "message_id" => "arbitrary"})

    assert result.assigns.flash["info"] =~ "held; verified"
    assert EmailSucks.Repo.get!(EmailSucks.Gmail.Controlled, "primary").repeat_revision == 1
  end

  test "controlled operations require CSRF and session, and ignore client message IDs", %{
    conn: conn
  } do
    for action <- ["hold", "release", "recover", "repeat"] do
      assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
        conn
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/gmail/controlled/#{action}")
      end

      Req.Test.stub(__MODULE__, fn _ -> flunk("unauthorized provider request") end)

      denied =
        conn
        |> bypass_csrf()
        |> post("/gmail/controlled/#{action}", %{"message_id" => "arbitrary"})

      assert redirected_to(denied) == "/"
      assert denied.assigns.flash["info"] =~ "Connect Gmail"
    end
  end

  test "batch actions require CSRF and a current session", %{conn: conn} do
    for action <- ["hold", "release", "recover", "repeat"] do
      assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
        conn |> put_private(:plug_skip_csrf_protection, false) |> post("/gmail/batch/#{action}")
      end

      Req.Test.stub(__MODULE__, fn _ -> flunk("unauthorized batch provider request") end)

      denied =
        conn |> bypass_csrf() |> post("/gmail/batch/#{action}", %{"message_ids" => ["arbitrary"]})

      assert redirected_to(denied) == "/"
      assert denied.assigns.flash["info"] =~ "Connect Gmail"
    end
  end

  test "disconnect requires CSRF, explicit intent and a current session", %{conn: conn} do
    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      conn
      |> put_private(:plug_skip_csrf_protection, false)
      |> post("/gmail/disconnect", %{confirm: "disconnect"})
    end

    Req.Test.stub(__MODULE__, fn _ -> flunk("unauthorized revoke") end)
    denied = conn |> bypass_csrf() |> post("/gmail/disconnect", %{confirm: "disconnect"})
    assert redirected_to(denied) == "/"
    assert denied.assigns.flash["info"] =~ "Connect Gmail"
    missing = conn |> bypass_csrf() |> post("/gmail/disconnect")
    assert redirected_to(missing) == "/"
    assert missing.assigns.flash["info"] =~ "Review"
  end

  test "disconnect completes through authenticated form and expires browser session", %{
    conn: conn
  } do
    {:ok, session} =
      Gmail.connect(%{subject: "subject", email: "owner@gmail.com"}, %{
        "access_token" => "private-access",
        "refresh_token" => "private-refresh",
        "expires_at" => System.system_time(:second) + 3600
      })

    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.request_path == "/revoke"
      Plug.Conn.send_resp(conn, 200, "")
    end)

    result =
      conn
      |> Plug.Test.init_test_session(gmail_session: session)
      |> bypass_csrf()
      |> post("/gmail/disconnect", %{confirm: "disconnect"})

    assert result.assigns.flash["info"] =~ "accepted revocation"
    assert get_session(result, :gmail_session) == nil
    assert Gmail.account(session) == nil
  end

  test "filter opt-in scope is saved in the encrypted server-side flow", %{conn: conn} do
    started = conn |> bypass_csrf() |> post("/auth/google", %{"purpose" => "filters"})
    assert redirected_to(started) =~ "gmail.settings.basic"
    flow_id = get_session(started, :gmail_flow)
    assert {:ok, flow} = Gmail.consume_flow(flow_id)
    assert "https://www.googleapis.com/auth/gmail.settings.basic" in flow.required_scopes
    assert Map.keys(get_session(started)) == ["gmail_flow"]
  end

  test "filter actions require CSRF and session", %{conn: conn} do
    for action <- ~w(activate recover inspect disable) do
      assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
        conn |> put_private(:plug_skip_csrf_protection, false) |> post("/gmail/filters/#{action}")
      end

      Req.Test.stub(__MODULE__, fn _ -> flunk("unauthorized filter request") end)
      denied = conn |> bypass_csrf() |> post("/gmail/filters/#{action}")
      assert denied.assigns.flash["info"] =~ "Connect Gmail"
    end

    public = get(conn, "/")
    assert Inertia.Testing.inertia_props(public).filters == nil
    refute Inertia.Testing.inertia_props(public).gmail_filter_settings
  end

  test "missing filter scope leaves ordinary connection usable and ignores client scope claims",
       %{conn: conn} do
    {:ok, session} =
      Gmail.connect(%{subject: "subject", email: "owner@gmail.com"}, %{
        "access_token" => "private-access",
        "refresh_token" => "private-refresh",
        "scope" => "https://www.googleapis.com/auth/gmail.modify",
        "expires_at" => System.system_time(:second) + 3600
      })

    Req.Test.stub(__MODULE__, fn _ -> flunk("must reject before any provider request") end)

    result =
      conn
      |> Plug.Test.init_test_session(gmail_session: session)
      |> bypass_csrf()
      |> post("/gmail/filters/activate", %{
        "scope" => "https://www.googleapis.com/auth/gmail.settings.basic",
        "subject" => "arbitrary"
      })

    assert result.assigns.flash["info"] =~ "separate filter permission form"
    assert Gmail.account(session).status == "connected"
    assert Gmail.filter_summary(session).state == "not_started"
    assert Gmail.filter_experiment(session, "arbitrary") == {:error, :invalid_transition}
  end

  defp bypass_csrf(conn), do: Plug.Conn.put_private(conn, :plug_skip_csrf_protection, true)
end
