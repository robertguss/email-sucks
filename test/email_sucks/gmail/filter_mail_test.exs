defmodule EmailSucks.Gmail.FilterMailTest do
  use ExUnit.Case, async: true
  alias EmailSucks.Gmail.FilterMail

  @nonce String.duplicate("a", 32)
  @base "/gmail/v1/users/me/"

  setup do
    %{config: [allowed_email: "owner@gmail.com", http_options: [plug: {Req.Test, __MODULE__}]]}
  end

  test "preflight searches the fixed fixture including spam and trash without a marker", %{
    config: config
  } do
    Req.Test.stub(__MODULE__, fn conn ->
      params = URI.decode_query(conn.query_string)
      assert params["includeSpamTrash"] == "true"
      assert params["q"] =~ "from:robertguss@gmail.com"
      assert params["q"] =~ "to:owner@gmail.com"
      assert params["q"] =~ "subject:phase0-filter-trash-001"
      refute params["q"] =~ "postman-probe"
      Req.Test.json(conn, %{"resultSizeEstimate" => 0})
    end)

    assert :ok = FilterMail.empty?(config, "token")
    Req.Test.stub(__MODULE__, &Req.Test.json(&1, %{"messages" => [%{"id" => "m1"}]}))
    assert {:error, :fixture_mismatch} = FilterMail.empty?(config, "token")
  end

  test "reads every page with the nonce query and only controlled metadata", %{config: config} do
    Req.Test.stub(__MODULE__, fn conn ->
      params = URI.decode_query(conn.query_string)

      case conn.request_path do
        @base <> "messages" ->
          assert params["q"] =~ ~s("postman-probe-#{@nonce}")
          assert params["includeSpamTrash"] == "true"

          if params["pageToken"] == "page2",
            do: Req.Test.json(conn, %{"messages" => [%{"id" => "m2"}]}),
            else:
              Req.Test.json(conn, %{"messages" => [%{"id" => "m1"}], "nextPageToken" => "page2"})

        @base <> "messages/" <> id ->
          assert params["format"] == "metadata"
          assert params["fields"] == "id,labelIds,payload/headers"

          assert URI.query_decoder(conn.query_string)
                 |> Enum.filter(&(elem(&1, 0) == "metadataHeaders"))
                 |> Enum.map(&elem(&1, 1)) == ["From", "To", "Subject"]

          Req.Test.json(conn, message(id))
      end
    end)

    assert {:ok, [%{"id" => "m1"}, %{"id" => "m2"}]} =
             FilterMail.messages(config, "token", @nonce)
  end

  test "held search uses a validated label and still checks fixture headers", %{config: config} do
    Req.Test.stub(__MODULE__, fn conn ->
      if conn.request_path == @base <> "messages" do
        params = URI.decode_query(conn.query_string)
        assert params["labelIds"] == "Label_123"
        refute Map.has_key?(params, "q")
        Req.Test.json(conn, %{"messages" => [%{"id" => "m1"}]})
      else
        Req.Test.json(conn, message("m1"))
      end
    end)

    assert {:ok, [_]} = FilterMail.held_messages(config, "token", "Label_123")
  end

  test "fails closed on malformed pages and loops", %{config: config} do
    for body <- [
          %{"messages" => nil},
          %{"messages" => [%{"id" => "../escape"}]},
          %{"messages" => [], "resultSizeEstimate" => 1},
          %{"messages" => [], "nextPageToken" => ""},
          %{"messages" => [%{"id" => "m1"}, %{"id" => "m1"}]}
        ] do
      Req.Test.stub(__MODULE__, &Req.Test.json(&1, body))
      assert {:error, _} = FilterMail.messages(config, "token", @nonce)
    end

    Req.Test.stub(__MODULE__, &Req.Test.json(&1, %{"messages" => [], "nextPageToken" => "same"}))
    assert {:error, :provider_unavailable} = FilterMail.messages(config, "token", @nonce)
  end

  test "rejects foreign, duplicated, missing, and malformed metadata", %{config: config} do
    good = message("m1")
    headers = good["payload"]["headers"]

    for bad <- [
          put_in(good, ["payload", "headers"], [
            %{"name" => "From", "value" => "foreign@gmail.com"} | tl(headers)
          ]),
          put_in(good, ["payload", "headers"], headers ++ [hd(headers)]),
          Map.delete(good, "payload"),
          Map.put(good, "id", "different"),
          Map.put(good, "labelIds", [nil]),
          put_in(good, ["payload", "headers"], [nil])
        ] do
      Req.Test.stub(__MODULE__, fn conn ->
        if conn.request_path == @base <> "messages",
          do: Req.Test.json(conn, %{"messages" => [%{"id" => "m1"}]}),
          else: Req.Test.json(conn, bad)
      end)

      assert {:error, _} = FilterMail.messages(config, "token", @nonce)
    end
  end

  test "rejects unsafe identifiers and nonces before making requests", %{config: config} do
    Req.Test.stub(__MODULE__, fn _ -> flunk("invalid input requested") end)

    for value <- [nil, "", "../escape", String.duplicate("A", 32)] do
      assert {:error, :fixture_mismatch} = FilterMail.messages(config, "token", value)
      assert {:error, :fixture_mismatch} = FilterMail.label(config, "token", value)
    end

    assert {:error, :fixture_mismatch} = FilterMail.held_messages(config, "token", "../escape")
  end

  test "resolves label before creation and reuses it after an uncertain create", %{config: config} do
    name = "Postman/Filter-probe-" <> @nonce
    Req.Test.expect(__MODULE__, fn conn -> Req.Test.json(conn, %{"labels" => []}) end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"name" => name}
      Plug.Conn.send_resp(conn, 503, "secret-provider-body")
    end)

    assert {:error, :provider_unavailable} = FilterMail.label(config, "token", @nonce)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      Req.Test.json(conn, %{"labels" => [%{"id" => "Label_123", "name" => name}]})
    end)

    assert {:ok, "Label_123"} = FilterMail.label(config, "token", @nonce)
    Req.Test.verify!()
  end

  test "rejects ambiguous labels and malformed label creates", %{config: config} do
    Req.Test.stub(__MODULE__, &Req.Test.json(&1, %{}))
    assert {:error, :provider_unavailable} = FilterMail.label(config, "token", @nonce)
    row = %{"id" => "Label_123", "name" => "Postman/Filter-probe-" <> @nonce}
    Req.Test.stub(__MODULE__, &Req.Test.json(&1, %{"labels" => [row, row]}))
    assert {:error, :fixture_mismatch} = FilterMail.label(config, "token", @nonce)

    Req.Test.stub(__MODULE__, fn conn ->
      if conn.method == "GET",
        do: Req.Test.json(conn, %{"labels" => []}),
        else: Req.Test.json(conn, %{"id" => "../escape"})
    end)

    assert {:error, :provider_unavailable} = FilterMail.label(config, "token", @nonce)
  end

  test "returns only safe provider failures", %{config: config} do
    for {status, body, expected} <- [
          {401, %{"secret" => "private"}, :reconnect_required},
          {403, %{"error" => %{"errors" => [%{"reason" => "insufficientPermissions"}]}},
           :missing_scope},
          {403, %{"error" => %{"details" => [%{"reason" => "SERVICE_DISABLED"}]}}, :api_disabled},
          {403, %{}, :permission_denied},
          {404, %{}, :not_found},
          {503, %{"secret" => "private"}, :provider_unavailable},
          {302, %{}, :provider_unavailable}
        ] do
      Req.Test.stub(__MODULE__, fn conn ->
        conn |> Plug.Conn.put_status(status) |> Req.Test.json(body)
      end)

      assert {:error, ^expected} = FilterMail.messages(config, "token", @nonce)
    end
  end

  defp message(id) do
    %{
      "id" => id,
      "labelIds" => ["UNREAD", "Label_123"],
      "payload" => %{
        "headers" => [
          %{"name" => "From", "value" => "Robert <robertguss@gmail.com>"},
          %{"name" => "To", "value" => "owner@gmail.com"},
          %{"name" => "Subject", "value" => "phase0-filter-trash-001"}
        ]
      }
    }
  end
end
