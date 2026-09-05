defmodule EmailSucks.Gmail.GoogleTest do
  use ExUnit.Case, async: true
  alias EmailSucks.Gmail.Google

  setup do
    config = [
      client_id: "test-client",
      client_secret: "test-secret",
      redirect_uri: "http://localhost:4000/auth/google/callback",
      allowed_email: "owner@gmail.com",
      http_options: [plug: {Req.Test, __MODULE__}]
    ]

    key = :public_key.generate_key({:rsa, 2048, 65537})
    pem = :public_key.pem_encode([:public_key.pem_entry_encode(:RSAPrivateKey, key)])
    jwk = %{"kty" => "RSA", "kid" => "test", "n" => b64(elem(key, 2)), "e" => b64(elem(key, 3))}
    {:ok, authorization} = Google.authorize(config)

    claims = %{
      "iss" => "https://accounts.google.com",
      "aud" => "test-client",
      "sub" => "google-subject",
      "email" => "owner@gmail.com",
      "email_verified" => true,
      "iat" => System.system_time(:second),
      "exp" => System.system_time(:second) + 3600,
      "nonce" => authorization.session_params.nonce
    }

    %{config: config, pem: pem, jwk: jwk, authorization: authorization, claims: claims}
  end

  test "requests identity and Gmail modification permission, with fresh state, nonce and S256 PKCE",
       ctx do
    params = URI.decode_query(URI.parse(ctx.authorization.url).query)
    assert params["code_challenge_method"] == "S256"
    assert params["access_type"] == "offline"
    refute Map.has_key?(params, "login_hint")

    assert String.split(params["scope"]) |> Enum.sort() ==
             Enum.sort(["openid", "email", "https://www.googleapis.com/auth/gmail.modify"])

    assert byte_size(params["nonce"]) >= 32
    {:ok, other} = Google.authorize(ctx.config)
    refute other.session_params == ctx.authorization.session_params
  end

  test "validates signed identity before returning minimal credentials", ctx do
    stub(ctx)
    assert {:ok, identity, token} = callback(ctx)
    assert identity == %{subject: "google-subject", email: "owner@gmail.com"}
    assert token["refresh_token"] == "refresh-test"
    refute Map.has_key?(token, "id_token")
  end

  for {label, override} <- [
        {"wrong account", %{"email" => "someone@gmail.com"}},
        {"unverified email", %{"email_verified" => false}},
        {"wrong audience", %{"aud" => "another-client"}},
        {"wrong issuer", %{"iss" => "https://attacker.test"}},
        {"wrong nonce", %{"nonce" => "another-browser"}},
        {"expired identity", %{"exp" => 0}}
      ] do
    test "rejects #{label}", ctx do
      stub(%{ctx | claims: Map.merge(ctx.claims, unquote(Macro.escape(override)))})
      assert {:error, _} = callback(ctx)
    end
  end

  test "rejects incorrect state before exchanging the code", ctx do
    Req.Test.stub(__MODULE__, fn _ -> flunk("must not exchange a code with incorrect state") end)

    assert {:error, :oauth_failed} =
             Google.callback(ctx.config, ctx.authorization.session_params, %{
               "state" => "wrong",
               "code" => "secret-code"
             })
  end

  test "rejects an ID token signed with a different key", ctx do
    other = :public_key.generate_key({:rsa, 2048, 65537})
    pem = :public_key.pem_encode([:public_key.pem_entry_encode(:RSAPrivateKey, other)])
    stub(%{ctx | pem: pem})
    assert {:error, :oauth_failed} = callback(ctx)
  end

  test "requires Gmail permission and sanitizes provider errors", ctx do
    stub(ctx, %{"scope" => "openid email https://www.googleapis.com/auth/gmail.readonly"})
    assert {:error, :missing_scope} = callback(ctx)

    Req.Test.stub(__MODULE__, fn conn ->
      Plug.Conn.send_resp(conn, 500, "secret-provider-body")
    end)

    assert {:error, :oauth_failed} = callback(ctx)
  end

  test "refresh preserves a non-rotated refresh token and distinguishes revoked grants", ctx do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "access_token" => "new-access",
        "expires_in" => 3600,
        "token_type" => "Bearer"
      })
    end)

    assert {:ok, token} = Google.refresh(ctx.config, %{"refresh_token" => "keep-refresh"})
    assert token["refresh_token"] == "keep-refresh"

    Req.Test.stub(__MODULE__, fn conn ->
      conn |> Plug.Conn.put_status(400) |> Req.Test.json(%{"error" => "invalid_grant"})
    end)

    assert {:error, :reconnect_required} =
             Google.refresh(ctx.config, %{"refresh_token" => "keep-refresh"})

    Req.Test.stub(__MODULE__, fn conn -> Plug.Conn.send_resp(conn, 503, "temporary") end)

    assert {:error, :provider_unavailable} =
             Google.refresh(ctx.config, %{"refresh_token" => "keep-refresh"})
  end

  defp callback(ctx),
    do:
      Google.callback(ctx.config, ctx.authorization.session_params, %{
        "state" => ctx.authorization.session_params.state,
        "code" => "test-code"
      })

  defp b64(n), do: n |> :binary.encode_unsigned() |> Base.url_encode64(padding: false)

  defp stub(ctx, overrides \\ %{}) do
    {:ok, jwt} =
      Assent.JWTAdapter.AssentJWT.sign(ctx.claims, "RS256", ctx.pem,
        json_library: Jason,
        private_key_id: "test"
      )

    token =
      Map.merge(
        %{
          "id_token" => jwt,
          "access_token" => "access-test",
          "refresh_token" => "refresh-test",
          "expires_in" => 3600,
          "scope" => "openid email https://www.googleapis.com/auth/gmail.modify",
          "token_type" => "Bearer"
        },
        overrides
      )

    Req.Test.stub(__MODULE__, fn conn ->
      case conn.request_path do
        "/token" ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          params = URI.decode_query(body)
          assert params["code_verifier"] == ctx.authorization.session_params.code_verifier
          Req.Test.json(conn, token)

        "/oauth2/v3/certs" ->
          Req.Test.json(conn, %{"keys" => [ctx.jwk]})
      end
    end)
  end
end
