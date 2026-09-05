defmodule EmailSucksWeb.BatchViewController do
  use EmailSucksWeb, :controller
  alias EmailSucks.Gmail
  plug :private_response

  def page(conn, _params) do
    case Gmail.account(get_session(conn, :gmail_session)) do
      nil ->
        redirect(conn, to: "/")

      _account ->
        render_inertia(conn, "BatchView", %{csrf_token: get_csrf_token()})
    end
  end

  def show(conn, _params), do: respond(conn, Gmail.batch_view(get_session(conn, :gmail_session)))

  def review(conn, params) do
    respond(
      conn,
      Gmail.review_batch_view(
        get_session(conn, :gmail_session),
        params["revision"],
        params["item_id"],
        params["reviewed"]
      )
    )
  end

  defp respond(conn, {:ok, result}), do: json(conn, result)

  defp respond(conn, {:error, reason}) do
    {status, error} =
      cond do
        reason in [:unauthorized, :reconnect_required, :missing_scope] ->
          {401, "reconnect_required"}

        reason in [:stale, :fixture_mismatch, :disconnect_pending, :operation_in_progress] ->
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
