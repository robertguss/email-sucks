defmodule EmailSucks.Gmail.InventoryTest do
  use ExUnit.Case, async: true
  alias EmailSucks.Gmail.Google
  @config [allowed_email: "fixture@example.test", http_options: [plug: {Req.Test, __MODULE__}]]

  defp respond(conn, overrides \\ %{}) do
    body =
      case conn.request_path do
        "/gmail/v1/users/me/settings/sendAs" ->
          %{
            "sendAs" => [
              %{
                "sendAsEmail" => "fixture@example.test",
                "isPrimary" => true,
                "isDefault" => true,
                "verificationStatus" => "accepted",
                "signature" => "private-signature",
                "smtpMsa" => %{"password" => "private"}
              }
            ]
          }

        "/gmail/v1/users/me/labels" ->
          %{
            "labels" => [
              %{"id" => "held", "name" => "Postman/Held"},
              %{"id" => "private", "name" => "private-label"}
            ]
          }

        "/gmail/v1/users/me/settings/filters" ->
          %{
            "filter" => [
              %{
                "id" => "candidate",
                "criteria" => %{"from" => "private-correspondent"},
                "action" => %{"addLabelIds" => ["held"], "removeLabelIds" => ["INBOX"]}
              }
            ]
          }
      end

    Req.Test.json(conn, Map.merge(body, overrides))
  end

  test "GET-only discovery returns allowlisted identities and candidate IDs, not private settings" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer fixture-token"]
      query = Plug.Conn.fetch_query_params(conn).query_params["fields"]
      refute query =~ "signature"
      refute query =~ "smtpMsa"
      refute query =~ "criteria"
      respond(conn)
    end)

    assert {:ok, result} = Google.inventory(@config, "fixture-token")
    assert result.filter_count == 1
    assert result.label_count == 2
    assert result.held_filter_candidates == [%{id: "candidate", removes_inbox?: true}]

    assert result.identities == [
             %{email: "fixture@example.test", primary?: true, default?: true, verified?: true}
           ]

    refute inspect(result) =~ "private"
  end

  test "an incorrect primary account stops discovery" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.request_path == "/gmail/v1/users/me/settings/sendAs"

      respond(conn, %{"sendAs" => [%{"sendAsEmail" => "other@example.test", "isPrimary" => true}]})
    end)

    assert {:error, :wrong_account} = Google.inventory(@config, "token")
  end

  test "malformed settings never masquerade as an empty inventory" do
    Req.Test.stub(__MODULE__, fn conn -> respond(conn, %{"filter" => nil}) end)
    assert {:error, :provider_unavailable} = Google.inventory(@config, "token")
  end

  test "provider errors are sanitized" do
    for {code, reason} <- [
          {401, :reconnect_required},
          {403, :permission_denied},
          {429, :provider_unavailable}
        ] do
      Req.Test.stub(__MODULE__, fn conn -> Plug.Conn.send_resp(conn, code, "private-error") end)
      assert {:error, ^reason} = Google.inventory(@config, "token")
    end
  end
end
