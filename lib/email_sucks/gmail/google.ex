defmodule EmailSucks.Gmail.Google do
  @moduledoc "Google's read-only OAuth boundary. Provider responses and credentials never become UI errors."
  @scope "https://www.googleapis.com/auth/gmail.readonly"
  # Google's published discovery document, checked 2026-09-04. Only fixed Google endpoints.
  @discovery %{
    "issuer" => "https://accounts.google.com",
    "authorization_endpoint" => "https://accounts.google.com/o/oauth2/v2/auth",
    "token_endpoint" => "https://oauth2.googleapis.com/token",
    "jwks_uri" => "https://www.googleapis.com/oauth2/v3/certs"
  }

  def authorize(config) do
    config
    |> strategy()
    |> Keyword.put(:nonce, random())
    |> Assent.Strategy.Google.authorize_url()
  end

  def callback(config, session, params) do
    with {:ok, %{user: user, token: token}} <-
           config
           |> strategy()
           |> Keyword.put(:session_params, session)
           |> Assent.Strategy.Google.callback(params),
         {:ok, identity} <- identity(user, config),
         true <- @scope in String.split(Map.get(token, "scope", "")),
         {:ok, token} <- credentials(token) do
      {:ok, identity, token}
    else
      false -> {:error, :missing_scope}
      {:error, :wrong_account} -> {:error, :wrong_account}
      _ -> {:error, :oauth_failed}
    end
  rescue
    # Treat malformed external responses as failures without rendering/logging their contents.
    _ -> {:error, :oauth_failed}
  end

  def refresh(config, previous) do
    form = [
      grant_type: "refresh_token",
      refresh_token: previous["refresh_token"],
      client_id: config[:client_id],
      client_secret: config[:client_secret]
    ]

    case request(config, method: :post, url: @discovery["token_endpoint"], form: form) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        body = Map.put_new(body, "refresh_token", previous["refresh_token"])

        case credentials(body) do
          {:ok, token} -> {:ok, token}
          _ -> {:error, :provider_unavailable}
        end

      {:ok, %{status: 400, body: %{"error" => "invalid_grant"}}} ->
        {:error, :reconnect_required}

      _ ->
        {:error, :provider_unavailable}
    end
  end

  def profile(config, access_token) do
    case request(config,
           method: :get,
           url: "https://gmail.googleapis.com/gmail/v1/users/me/profile",
           headers: [{"authorization", "Bearer " <> access_token}]
         ) do
      {:ok, %{status: 200, body: %{"emailAddress" => email}}} when is_binary(email) ->
        if String.downcase(email) == config[:allowed_email],
          do: :ok,
          else: {:error, :wrong_account}

      {:ok, %{status: 401}} ->
        {:error, :reconnect_required}

      {:ok, %{status: 403}} ->
        {:error, :missing_scope}

      _ ->
        {:error, :provider_unavailable}
    end
  end

  def recent_messages(config, access_token) do
    with {:ok, body} <-
           mail_get(config, access_token, "",
             maxResults: 5,
             labelIds: "INBOX",
             includeSpamTrash: false
           ),
         messages when is_list(messages) <- Map.get(body, "messages", []) do
      messages
      |> Enum.take(5)
      |> Enum.reduce_while({:ok, []}, fn message, {:ok, acc} ->
        case message_metadata(config, access_token, message) do
          {:ok, item} -> {:cont, {:ok, [item | acc]}}
          {:error, :not_found} -> {:cont, {:ok, acc}}
          error -> {:halt, error}
        end
      end)
      |> case do
        {:ok, items} -> {:ok, Enum.reverse(items)}
        error -> error
      end
    else
      {:error, _} = error -> error
      _ -> {:error, :provider_unavailable}
    end
  end

  defp message_metadata(config, token, %{"id" => id}) when is_binary(id) do
    if Regex.match?(~r/\A[a-zA-Z0-9_-]+\z/, id) do
      with {:ok, body} <-
             mail_get(config, token, "/" <> id,
               format: "metadata",
               metadataHeaders: "From",
               metadataHeaders: "Subject",
               fields: "id,internalDate,labelIds,payload/headers"
             ),
           %{"internalDate" => date, "payload" => %{"headers" => headers}} <- body,
           true <- is_binary(date) and is_list(headers),
           {milliseconds, ""} <- Integer.parse(date),
           {:ok, received} <- DateTime.from_unix(milliseconds, :millisecond) do
        header = fn name, fallback ->
          Enum.find_value(headers, fallback, fn
            %{"name" => key, "value" => value} when is_binary(key) and is_binary(value) ->
              if String.downcase(key) == name and String.trim(value) != "",
                do: String.slice(value, 0, 1000)

            _ ->
              nil
          end)
        end

        {:ok,
         %{
           id: id,
           sender: header.("from", "Unknown sender"),
           subject: header.("subject", "(No subject)"),
           received_at: DateTime.to_iso8601(received),
           unread: "UNREAD" in Map.get(body, "labelIds", [])
         }}
      else
        {:error, _} = error -> error
        _ -> {:error, :provider_unavailable}
      end
    else
      {:error, :provider_unavailable}
    end
  end

  defp message_metadata(_, _, _), do: {:error, :provider_unavailable}

  defp mail_get(config, token, path, params) do
    url =
      "https://gmail.googleapis.com/gmail/v1/users/me/messages" <>
        path <> "?" <> URI.encode_query(params)

    case request(config, method: :get, url: url, headers: [{"authorization", "Bearer " <> token}]) do
      {:ok, %{status: 200, body: body}} when is_map(body) -> {:ok, body}
      {:ok, %{status: 401}} -> {:error, :reconnect_required}
      {:ok, %{status: 403}} -> {:error, :missing_scope}
      {:ok, %{status: 404}} -> {:error, :not_found}
      _ -> {:error, :provider_unavailable}
    end
  end

  def random, do: :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

  defp strategy(config) do
    [
      client_id: Keyword.fetch!(config, :client_id),
      client_secret: Keyword.fetch!(config, :client_secret),
      redirect_uri: Keyword.fetch!(config, :redirect_uri),
      code_verifier: true,
      openid_configuration: @discovery,
      id_token_signed_response_alg: "RS256",
      id_token_ttl_seconds: 600,
      http_adapter: {Assent.HTTPAdapter.Req, http_options(config)},
      authorization_params: [
        scope: "email #{@scope}",
        access_type: "offline",
        prompt: "consent"
      ]
    ]
  end

  defp identity(%{"sub" => subject, "email" => email, "email_verified" => true}, config)
       when is_binary(subject) and byte_size(subject) > 0 and is_binary(email) do
    if String.downcase(email) == config[:allowed_email],
      do: {:ok, %{subject: subject, email: String.downcase(email)}},
      else: {:error, :wrong_account}
  end

  defp identity(_, _), do: {:error, :wrong_account}

  defp credentials(%{"access_token" => access, "expires_in" => ttl, "token_type" => type} = token)
       when is_binary(access) and byte_size(access) > 0 and is_binary(type) and is_integer(ttl) and
              ttl > 0 and
              ttl <= 86_400 do
    if String.downcase(type) == "bearer" do
      {:ok,
       token
       |> Map.take(~w(access_token refresh_token scope))
       |> Map.put("expires_at", System.system_time(:second) + ttl)}
    else
      {:error, :invalid_token}
    end
  end

  defp credentials(_), do: {:error, :invalid_token}

  defp http_options(config) do
    Keyword.merge(
      [retry: false, redirect: false, receive_timeout: 10_000, connect_options: [timeout: 5_000]],
      Keyword.get(config, :http_options, [])
    )
  end

  defp request(config, opts), do: Req.request(Keyword.merge(http_options(config), opts))
end
