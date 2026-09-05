defmodule EmailSucksWeb.GoogleController do
  use EmailSucksWeb, :controller
  alias EmailSucks.Gmail

  plug :private_response

  def start(conn, params) do
    purpose = if params["purpose"] == "filters", do: "filters", else: nil

    case Gmail.begin_connection(purpose) do
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

  def filters(conn, %{"action" => action}), do: filter_action(conn, action, "primary")

  def arrival_filters(conn, %{"action" => action}),
    do: filter_action(conn, action, "arrival-primary-v1")

  defp filter_action(conn, action, profile) do
    case Gmail.filter_experiment(get_session(conn, :gmail_session), action, profile) do
      {:ok, %{state: state}} ->
        conn
        |> put_flash(
          :info,
          "Filter experiment #{state}. Review saved progress before continuing."
        )
        |> redirect(to: ~p"/")

      {:error, reason} ->
        failure(conn, reason)
    end
  end

  def batch(conn, %{"action" => action} = params) do
    case Gmail.batch(get_session(conn, :gmail_session), action, params["repeat_revision"]) do
      {:ok, %{state: state}} ->
        conn
        |> put_flash(
          :info,
          "Controlled batch #{state}; all saved messages verified against Gmail."
        )
        |> redirect(to: ~p"/")

      {:error, reason} ->
        failure(conn, reason)
    end
  end

  def controlled(conn, %{"action" => action} = params) do
    case Gmail.controlled(get_session(conn, :gmail_session), action, params["repeat_revision"]) do
      {:ok, %{state: state}} ->
        conn
        |> put_flash(:info, "Controlled message #{state}; verified against Gmail just now.")
        |> redirect(to: ~p"/")

      {:error, reason} ->
        failure(conn, reason)
    end
  end

  def disconnect(conn, %{"confirm" => "disconnect"}) do
    case Gmail.disconnect(get_session(conn, :gmail_session)) do
      {:ok, outcome} ->
        message =
          if outcome == :revoked,
            do:
              "Controlled mail recovery checked. Google accepted revocation; saved credentials and browser access were removed. Google may take time to apply revocation.",
            else:
              "Controlled mail recovery checked. Google reported the saved token was already invalid. Saved credentials were removed; review Google Account permissions for any remaining project access."

        conn
        |> clear_session()
        |> configure_session(renew: true)
        |> put_flash(:info, message)
        |> redirect(to: ~p"/")

      {:error, reason} ->
        failure(conn, reason)
    end
  end

  def disconnect(conn, _params) do
    conn
    |> put_flash(:info, "Review the safe disconnect panel before confirming.")
    |> redirect(to: ~p"/")
  end

  def logout(conn, _params) do
    Gmail.logout(get_session(conn, :gmail_session))
    conn |> clear_session() |> configure_session(drop: true) |> redirect(to: ~p"/")
  end

  defp failure(conn, reason) do
    message =
      case reason do
        :disconnect_pending ->
          "Disconnect is pending. Resume safe disconnect to complete recovery and remove access."

        :revocation_unconfirmed ->
          "Mail recovery was verified, but Google has not confirmed revocation. Resume disconnect; saved credentials remain until the outcome is known."

        :disconnect_completed ->
          "The earlier disconnect is complete. Connect Gmail again if you want to resume using this app."

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

        reason when reason in [:filter_creation_uncertain, :filter_ownership_uncertain] ->
          "Gmail has not confirmed which test filters exist. No duplicate filters will be created. Retry recovery; keep access until cleanup is verified."

        reason when reason in [:filter_drift, :filter_baseline_changed] ->
          "Gmail filters changed outside the saved experiment. Review the filters in Gmail; the app will not delete changed or unrelated filters."

        :filter_cleanup_pending ->
          "Filter cleanup or held-mail recovery is still unverified. Retry cleanup before disconnecting."

        :filter_settings_required ->
          "This experiment needs Gmail filter settings and modification permission. Use the separate filter permission form; your ordinary Gmail connection is unchanged."

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
