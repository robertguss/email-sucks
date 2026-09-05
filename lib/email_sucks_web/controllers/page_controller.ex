defmodule EmailSucksWeb.PageController do
  use EmailSucksWeb, :controller

  def home(conn, _params) do
    account = EmailSucks.Gmail.account(get_session(conn, :gmail_session))

    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("referrer-policy", "no-referrer")
    |> render_inertia("PhaseZero", %{
      gmail_configured: EmailSucks.Gmail.configured?(),
      gmail_connected:
        account != nil && account.status == "connected" && is_nil(account.disconnect_phase),
      gmail_disconnect_phase: account && account.disconnect_phase,
      gmail_email: account && account.email,
      gmail_reconnect: account != nil && account.status == "reconnect_required",
      gmail_checked: account != nil && account.checked_at != nil,
      controlled: EmailSucks.Gmail.controlled_summary(get_session(conn, :gmail_session)),
      csrf_token: get_csrf_token(),
      notice: conn.assigns.flash["info"]
    })
  end

  def contract(conn, _params) do
    render_inertia(conn, "Contract")
  end
end
