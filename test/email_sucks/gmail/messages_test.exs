defmodule EmailSucks.Gmail.MessagesTest do
  use ExUnit.Case, async: true
  alias EmailSucks.Gmail.Google
  @config [http_options: [plug: {Req.Test, __MODULE__}]]

  test "reads only five Inbox metadata records and returns an allowlist of fields" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer private-token"]
      conn = Plug.Conn.fetch_query_params(conn)

      case conn.request_path do
        "/gmail/v1/users/me/messages" ->
          assert conn.query_params["maxResults"] == "5"
          assert conn.query_params["labelIds"] == "INBOX"
          Req.Test.json(conn, %{"messages" => [%{"id" => "abc"}]})

        "/gmail/v1/users/me/messages/abc" ->
          assert conn.query_params["format"] == "metadata"

          assert URI.query_decoder(conn.query_string)
                 |> Enum.filter(&(elem(&1, 0) == "metadataHeaders")) == [
                   {"metadataHeaders", "From"},
                   {"metadataHeaders", "Subject"}
                 ]

          Req.Test.json(conn, %{
            "id" => "abc",
            "internalDate" => "1700000000000",
            "labelIds" => ["INBOX", "UNREAD"],
            "snippet" => "private body",
            "payload" => %{
              "body" => %{"data" => "private"},
              "headers" => [
                %{"name" => "from", "value" => "Sender"},
                %{"name" => "Subject", "value" => "<script>text only</script>"}
              ]
            }
          })
      end
    end)

    assert {:ok, [message]} = Google.recent_messages(@config, "private-token")

    assert message == %{
             id: "abc",
             sender: "Sender",
             subject: "<script>text only</script>",
             received_at: "2023-11-14T22:13:20.000Z",
             unread: true
           }
  end

  test "empty Inbox is successful; disappearing messages are skipped" do
    Req.Test.stub(__MODULE__, fn conn -> Req.Test.json(conn, %{"resultSizeEstimate" => 0}) end)
    assert {:ok, []} = Google.recent_messages(@config, "token")

    Req.Test.stub(__MODULE__, fn conn ->
      if String.ends_with?(conn.request_path, "/messages"),
        do: Req.Test.json(conn, %{"messages" => [%{"id" => "gone"}]}),
        else: Plug.Conn.send_resp(conn, 404, "not found")
    end)

    assert {:ok, []} = Google.recent_messages(@config, "token")
  end

  test "provider errors return safe codes, not bodies or a misleading empty list" do
    for {status, error} <- [
          {401, :reconnect_required},
          {403, :missing_scope},
          {429, :provider_unavailable},
          {503, :provider_unavailable}
        ] do
      Req.Test.stub(__MODULE__, fn conn ->
        Plug.Conn.send_resp(conn, status, "private-provider-body")
      end)

      assert {:error, ^error} = Google.recent_messages(@config, "token")
    end
  end
end
