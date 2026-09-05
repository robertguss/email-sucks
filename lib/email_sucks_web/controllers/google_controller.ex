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
          "Gmail connected. The controlled test can hold and release one fixture message."
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

  def messages(conn, _params) do
    case Gmail.recent_messages(get_session(conn, :gmail_session)) do
      {:ok, messages} ->
        json(conn, %{messages: messages})

      {:error, reason} ->
        status =
          if reason in [:unauthorized, :reconnect_required, :missing_scope], do: 401, else: 503

        conn
        |> put_status(status)
        |> json(%{error: if(status == 401, do: "reconnect_required", else: "unavailable")})
    end
  end

  def controlled(conn, %{"action" => action}) do
    case Gmail.controlled(get_session(conn, :gmail_session), action) do
      {:ok, %{state: state}} ->
        conn
        |> put_flash(:info, "Controlled message #{state}; verified against Gmail just now.")
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
        :api_disabled ->
          "The Gmail API is disabled in the Google project. Enable it before retrying."

        :permission_denied ->
          "Google denied this request. Check the Google project and account permissions."

        :fixture_mismatch ->
          "The controlled fixture did not match exactly, or is in Trash, Spam, or Drafts. Any saved experiment remains available for recovery."

        :verification_failed ->
          "Gmail labels do not match the saved intent. Success is unverified. Use Recover / verify or release to Inbox."

        :not_found ->
          "The saved message or label is unavailable in Gmail. The experiment is retained for recovery."

        :operation_in_progress ->
          "Another controlled operation is running. Wait for it to finish, then recover or verify."

        :invalid_transition ->
          "That action is unavailable for the saved experiment. Refresh this page."

        :wrong_account ->
          "That Google account is not allowed for this personal prototype."

        :missing_scope ->
          "Gmail modification permission is missing. Reconnect and allow that permission."

        :missing_refresh_token ->
          "Google did not grant offline access. Please reconnect and approve access."

        :reconnect_required ->
          "Google access has expired or been revoked. Please reconnect Gmail."

        :provider_unavailable ->
          "Google could not confirm the operation. Any saved intent remains pending; use Recover / verify before assuming success."

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
