defmodule EmailSucksWeb.HealthController do
  use EmailSucksWeb, :controller

  def ready(conn, _params) do
    case Ecto.Adapters.SQL.query(EmailSucks.Repo, "SELECT 1", [], timeout: 2_000, log: false) do
      {:ok, _} -> json(conn, %{status: "ok"})
      {:error, _} -> unavailable(conn)
    end
  rescue
    DBConnection.ConnectionError -> unavailable(conn)
  end

  defp unavailable(conn),
    do: conn |> put_status(:service_unavailable) |> json(%{status: "unavailable"})
end
