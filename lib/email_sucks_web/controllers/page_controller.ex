defmodule EmailSucksWeb.PageController do
  use EmailSucksWeb, :controller

  def home(conn, _params) do
    render_inertia(conn, "PhaseZero", %{gmail_connected: false})
  end

  def contract(conn, _params) do
    render_inertia(conn, "Contract")
  end
end
