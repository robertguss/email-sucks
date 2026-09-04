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
            "scope" => "openid email https://www.googleapis.com/auth/gmail.readonly"
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

  defp bypass_csrf(conn), do: Plug.Conn.put_private(conn, :plug_skip_csrf_protection, true)
end
