defmodule EmailSucksWeb.PageControllerTest do
  use EmailSucksWeb.ConnCase

  test "the initial page exposes a safe, disconnected Phase 0 state", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "PhaseZero"
    assert Inertia.Testing.inertia_props(conn).gmail_connected == false
  end

  test "Inertia navigation returns the contract without a full HTML document", %{conn: conn} do
    initial = get(conn, ~p"/")

    conn =
      conn
      |> recycle()
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", initial.private.inertia_version)
      |> get(~p"/phase-0/contract")

    assert json_response(conn, 200)["component"] == "Contract"
  end

  test "readiness checks the database without exposing connection details", %{conn: conn} do
    conn = get(conn, ~p"/health/ready")
    assert json_response(conn, 200) == %{"status" => "ok"}
  end
end
