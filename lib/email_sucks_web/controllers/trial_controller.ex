defmodule EmailSucksWeb.TrialController do
  use EmailSucksWeb, :controller
  alias EmailSucks.Gmail
  plug :private_response
  def show(conn, _), do: respond(conn, Gmail.trial_summary(get_session(conn, :gmail_session)))
  def start(conn, _), do: respond(conn, Gmail.trial_start(get_session(conn, :gmail_session)))

  def check_now(conn, params),
    do:
      respond(
        conn,
        Gmail.trial_check_now(get_session(conn, :gmail_session), params["request_id"])
      )

  def stop(conn, _), do: respond(conn, Gmail.trial_stop(get_session(conn, :gmail_session)))
  def view(conn, _), do: respond(conn, Gmail.trial_view(get_session(conn, :gmail_session)))

  def review(conn, params),
    do:
      respond(
        conn,
        Gmail.trial_review(
          get_session(conn, :gmail_session),
          params["run_id"],
          params["revision"],
          params["item_id"],
          params["reviewed"]
        )
      )

  defp respond(conn, {:ok, data}), do: json(conn, data)

  defp respond(conn, {:error, reason}) do
    {status, error} =
      cond do
        reason in [:unauthorized, :reconnect_required, :missing_scope, :filter_settings_required] ->
          {401, "reconnect_required"}

        reason in [:stale, :invalid_transition, :disconnect_pending, :operation_in_progress] ->
          {409, "stale"}

        true ->
          {503, "unavailable"}
      end

    conn |> put_status(status) |> json(%{error: error})
  end

  defp private_response(conn, _) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("referrer-policy", "no-referrer")
  end
end
