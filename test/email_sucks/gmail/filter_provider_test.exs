defmodule EmailSucks.Gmail.FilterProviderTest do
  use ExUnit.Case, async: true
  alias EmailSucks.Gmail.FilterProvider

  setup do
    %{
      config: [
        allowed_email: "owner@gmail.com",
        filter_lab_label_id: "Label_lab",
        http_options: [plug: {Req.Test, __MODULE__}]
      ]
    }
  end

  test "lists full filters from the fixed account endpoint", %{config: config} do
    row = Map.put(spec(), "id", "filter_1")

    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.host == "gmail.googleapis.com"
      assert conn.request_path == "/gmail/v1/users/me/settings/filters"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer access-test"]
      Req.Test.json(conn, %{"filter" => [row]})
    end)

    assert {:ok, [^row]} = FilterProvider.list(config, "access-test")
  end

  test "accepts explicit or omitted empty list but rejects malformed and duplicate results", %{
    config: config
  } do
    for body <- [%{}, %{"filter" => []}] do
      respond(body)
      assert {:ok, []} = FilterProvider.list(config, "access-test")
    end

    row = Map.put(spec(), "id", "filter_1")

    for body <- [
          nil,
          [],
          %{"filters" => []},
          %{"error" => "private"},
          %{"filter" => nil},
          %{"filter" => [%{"id" => "only-id"}]},
          %{"filter" => [Map.put(row, "criteria", %{"hasAttachment" => "yes"})]},
          %{"filter" => [Map.put(row, "action", %{"addLabelIds" => [nil]})]},
          %{"filter" => [Map.put(row, "id", "../foreign")]},
          %{"filter" => [row, row]}
        ] do
      respond(body)
      assert {:error, :provider_unavailable} = FilterProvider.list(config, "access-test")
    end
  end

  test "preserves valid existing foreign filters for ownership comparisons", %{config: config} do
    row = %{
      "id" => "foreign",
      "criteria" => %{
        "query" => "from:newsletter",
        "size" => 100,
        "sizeComparison" => "larger",
        "excludeChats" => true
      },
      "action" => %{"forward" => "archive@example.com", "removeLabelIds" => ["INBOX"]}
    }

    respond(%{"filter" => [row]})
    assert {:ok, [^row]} = FilterProvider.list(config, "access-test")
  end

  test "creates only the exact trash or bound lab-label experiment payload", %{config: config} do
    for specification <- [
          spec(),
          put_in(spec(), ["action"], %{
            "addLabelIds" => ["Label_lab"],
            "removeLabelIds" => ["INBOX"]
          })
        ] do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/gmail/v1/users/me/settings/filters"
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == specification
        Req.Test.json(conn, Map.put(specification, "id", "created_1"))
      end)

      assert {:ok, %{"id" => "created_1"}} =
               FilterProvider.create(config, "access-test", specification)
    end
  end

  test "refuses widened criteria, forwarding, unbound labels and malformed input without requests",
       %{config: config} do
    Req.Test.stub(__MODULE__, fn _ -> flunk("invalid specification must not reach Gmail") end)

    for specification <- [
          nil,
          %{},
          Map.put(spec(), "id", "existing"),
          put_in(spec(), ["criteria", "from"], "someone@gmail.com"),
          put_in(spec(), ["criteria", "to"], "other@gmail.com"),
          put_in(spec(), ["criteria", "subject"], "phase0"),
          update_in(spec(), ["criteria"], &Map.delete(&1, "query")),
          put_in(spec(), ["criteria", "query"], "postman-probe-0123456789abcdef0123456789abcdef"),
          put_in(
            spec(),
            ["criteria", "query"],
            "\"postman-probe-0123456789abcdef0123456789abcdef\" OR is:unread"
          ),
          update_in(spec(), ["criteria"], &Map.put(&1, "query", "is:unread")),
          put_in(spec(), ["action"], %{"addLabelIds" => ["TRASH", "Label_lab"]}),
          put_in(spec(), ["action"], %{"forward" => "someone@gmail.com"}),
          put_in(spec(), ["action"], %{
            "addLabelIds" => ["Label_foreign"],
            "removeLabelIds" => ["INBOX"]
          }),
          put_in(spec(), ["action"], %{
            "addLabelIds" => ["Label_lab"],
            "removeLabelIds" => ["UNREAD"]
          })
        ] do
      assert {:error, :fixture_mismatch} =
               FilterProvider.create(config, "access-test", specification)
    end
  end

  test "does not accept missing or foreign create confirmations", %{config: config} do
    row = Map.put(spec(), "id", "created_1")

    for body <- [
          %{},
          %{"id" => "created_1"},
          Map.put(row, "id", "../bad"),
          put_in(row, ["criteria", "to"], "someone@gmail.com"),
          put_in(row, ["action"], %{"addLabelIds" => ["INBOX"]})
        ] do
      respond(body)

      assert {:error, :provider_unavailable} =
               FilterProvider.create(config, "access-test", spec())
    end
  end

  test "hold creation requires a safe label explicitly bound by the caller", %{config: config} do
    Req.Test.stub(__MODULE__, fn _ -> flunk("unbound label must not reach Gmail") end)

    for label <- [nil, "TRASH", "Label_../bad", "Label_"] do
      config = Keyword.put(config, :filter_lab_label_id, label)

      specification =
        put_in(spec(), ["action"], %{"addLabelIds" => [label], "removeLabelIds" => ["INBOX"]})

      assert {:error, :fixture_mismatch} =
               FilterProvider.create(config, "access-test", specification)
    end
  end

  test "delete confirms successful and already absent IDs", %{config: config} do
    for status <- [200, 204, 404] do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/gmail/v1/users/me/settings/filters/saved_1"
        Plug.Conn.send_resp(conn, status, "")
      end)

      assert :ok = FilterProvider.delete(config, "access-test", "saved_1")
    end
  end

  test "path injection and invalid credentials never reach Gmail", %{config: config} do
    Req.Test.stub(__MODULE__, fn _ -> flunk("unsafe request") end)

    for id <- [nil, "", "../other", "x?query=1", "x/y", "x%2Fy", "x\n"] do
      assert {:error, :fixture_mismatch} = FilterProvider.delete(config, "access-test", id)
    end

    for token <- [nil, "", "a\r\nb"] do
      assert {:error, :reconnect_required} = FilterProvider.list(config, token)
    end
  end

  test "returns safe authorization and transient errors for all operations", %{config: config} do
    for {status, body, expected} <- [
          {401, %{"private" => "secret"}, :reconnect_required},
          {403, %{"error" => %{"errors" => [%{"reason" => "insufficientPermissions"}]}},
           :missing_scope},
          {403, %{"error" => %{"details" => [%{"reason" => "SERVICE_DISABLED"}]}}, :api_disabled},
          {403, %{"private" => "secret"}, :permission_denied},
          {429, %{"private" => "secret"}, :provider_unavailable},
          {503, %{"private" => "secret"}, :provider_unavailable}
        ] do
      respond(body, status)
      assert {:error, ^expected} = FilterProvider.list(config, "access-test")
      assert {:error, ^expected} = FilterProvider.create(config, "access-test", spec())
      assert {:error, ^expected} = FilterProvider.delete(config, "access-test", "saved_1")
    end
  end

  test "does not follow redirects or retry ambiguous creates even with caller overrides", %{
    config: config
  } do
    config =
      Keyword.update!(
        config,
        :http_options,
        &Keyword.merge(&1, retry: :safe_transient, redirect: true)
      )

    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("location", "https://attacker.example/private")
      |> Plug.Conn.send_resp(307, "")
    end)

    assert {:error, :provider_unavailable} = FilterProvider.create(config, "access-test", spec())
    Req.Test.expect(__MODULE__, fn conn -> Plug.Conn.send_resp(conn, 503, "private") end)
    assert {:error, :provider_unavailable} = FilterProvider.create(config, "access-test", spec())
  end

  defp respond(body, status \\ 200) do
    Req.Test.stub(__MODULE__, fn conn ->
      conn |> Plug.Conn.put_status(status) |> Req.Test.json(body)
    end)
  end

  defp spec do
    %{
      "criteria" => %{
        "from" => "robertguss@gmail.com",
        "to" => "owner@gmail.com",
        "subject" => "phase0-filter-trash-001",
        "query" => "\"postman-probe-0123456789abcdef0123456789abcdef\""
      },
      "action" => %{"addLabelIds" => ["TRASH"]}
    }
  end
end
