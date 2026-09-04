defmodule EmailSucksWeb.GoogleController do
  use EmailSucksWeb, :controller
  alias EmailSucks.Gmail

  plug :private_response

  def start(conn, _params) do
    case Gmail.begin_connection() do
      {:ok, flow, url} -> conn |> put_session(:gmail_flow, flow) |> redirect(external: url)
      {:error, reason} -> failure(conn, reason)
    end
  end

  def callback(conn, params) do
    flow = get_session(conn, :gmail_flow)
    conn = delete_session(conn, :gmail_flow)

    case Gmail.finish_connection(flow, Map.take(params, ~w(code state error))) do
      {:ok, session} ->
        conn
        |> clear_session()
        |> configure_session(renew: true)
        |> put_session(:gmail_session, session)
        |> put_flash(
          :info,
          "Gmail connected with read-only access. You can now check the connection."
        )
        |> redirect(to: ~p"/")

      {:error, reason} ->
        failure(conn, reason)
    end
  end

  def check(conn, _params) do
    case Gmail.check(get_session(conn, :gmail_session)) do
      :ok ->
        conn
        |> put_flash(:info, "Gmail connection verified. No messages were downloaded or changed.")
        |> redirect(to: ~p"/")

      {:error, reason} ->
        failure(conn, reason)
    end
  end

  def logout(conn, _params) do
    Gmail.logout(get_session(conn, :gmail_session))
    conn |> clear_session() |> configure_session(drop: true) |> redirect(to: ~p"/")
  end

  defp failure(conn, reason) do
    message =
      case reason do
        :wrong_account ->
          "That Google account is not allowed for this personal prototype."

        :missing_scope ->
          "Gmail read-only permission is missing. Reconnect and allow that permission."

        :missing_refresh_token ->
          "Google did not grant offline access. Please reconnect and approve access."

        :reconnect_required ->
          "Google access has expired or been revoked. Please reconnect Gmail."

        :provider_unavailable ->
          "Google could not be reached. Your connection is saved; please try again."

        :refresh_in_progress ->
          "A connection check is already refreshing access. Please try again shortly."

        :rate_limited ->
          "Too many connection attempts. Please wait one minute and try again."

        :not_configured ->
          "Google connection setup is not configured on this server."

        :unauthorized ->
          "Connect Gmail before checking the connection."

        _ ->
          "The Google connection could not be completed. Please start again."
      end

    conn |> put_flash(:info, message) |> redirect(to: ~p"/")
  end

  defp private_response(conn, _opts) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("referrer-policy", "no-referrer")
  end
end
