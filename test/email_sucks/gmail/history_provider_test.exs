defmodule EmailSucks.Gmail.HistoryProviderTest do
  use ExUnit.Case, async: true
  alias EmailSucks.Gmail.HistoryProvider
  @config [http_options: [plug: {Req.Test, __MODULE__}]]

  test "profile and minimal metadata discard unexpected private fields" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"

      if String.ends_with?(conn.request_path, "/profile") do
        assert URI.decode_query(conn.query_string)["fields"] == "historyId"
        Req.Test.json(conn, %{"historyId" => "90", "emailAddress" => "private"})
      else
        assert URI.decode_query(conn.query_string) == %{
                 "format" => "minimal",
                 "fields" => "id,labelIds"
               }

        Req.Test.json(conn, %{"id" => "m1", "labelIds" => ["UNREAD"], "snippet" => "private"})
      end
    end)

    assert {:ok, "90"} = HistoryProvider.profile(@config, "token")

    assert {:ok, %{"available" => true, "labels" => ["UNREAD"]}} =
             HistoryProvider.message(@config, "token", "m1")
  end

  test "paginates, deduplicates gapped history and filters unknown IDs" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      params = URI.decode_query(conn.query_string)
      assert params["startHistoryId"] == "90"

      if params["pageToken"] do
        Req.Test.json(conn, %{
          "historyId" => "1000",
          "history" => [%{"id" => "999", "messagesDeleted" => [%{"message" => %{"id" => "m1"}}]}]
        })
      else
        Req.Test.json(conn, %{
          "historyId" => "999",
          "nextPageToken" => "next",
          "history" => [
            %{
              "id" => "100",
              "messages" => [%{"id" => "m1"}, %{"id" => "foreign"}],
              "labelsAdded" => [%{"message" => %{"id" => "m1"}}]
            }
          ]
        })
      end
    end)

    assert {:ok, ["m1"], "1000"} = HistoryProvider.changes(@config, "token", "90", ["m1", "m2"])
  end

  test "history404 and message404 have distinct meanings; other errors stay failures" do
    Req.Test.stub(__MODULE__, &Plug.Conn.send_resp(&1, 404, "private"))
    assert {:error, :history_expired} = HistoryProvider.changes(@config, "t", "90", ["m1"])
    assert {:ok, %{"available" => false}} = HistoryProvider.message(@config, "t", "m1")

    for {status, expected} <- [
          {401, :reconnect_required},
          {403, :permission_denied},
          {429, :provider_unavailable},
          {503, :provider_unavailable},
          {302, :provider_unavailable}
        ] do
      Req.Test.stub(__MODULE__, &Plug.Conn.send_resp(&1, status, "private"))
      assert {:error, ^expected} = HistoryProvider.message(@config, "t", "m1")
    end
  end

  test "rejects nested malformed history events rather than flattening them" do
    Req.Test.stub(
      __MODULE__,
      &Req.Test.json(&1, %{
        "historyId" => "100",
        "history" => [%{"id" => "99", "messagesAdded" => [[%{"message" => %{"id" => "m1"}}]]}]
      })
    )

    assert {:error, :provider_unavailable} = HistoryProvider.changes(@config, "t", "90", ["m1"])
  end

  test "caps history traversal visibly and never retries failed requests" do
    Process.put(:calls, 0)

    Req.Test.stub(__MODULE__, fn conn ->
      n = Process.get(:calls) + 1
      Process.put(:calls, n)
      Req.Test.json(conn, %{"historyId" => "100", "nextPageToken" => "page#{n}"})
    end)

    assert {:error, :history_limit_exceeded} = HistoryProvider.changes(@config, "t", "90", ["m1"])
    assert Process.get(:calls) == 20
    Process.put(:calls, 0)

    Req.Test.stub(__MODULE__, fn conn ->
      Process.put(:calls, Process.get(:calls) + 1)
      Plug.Conn.send_resp(conn, 503, "private")
    end)

    assert {:error, :provider_unavailable} = HistoryProvider.message(@config, "t", "m1")
    assert Process.get(:calls) == 1
  end

  test "rejects mismatched and malformed minimal messages" do
    for body <- [
          %{"id" => "wrong"},
          %{"id" => "m1", "labelIds" => nil},
          %{"id" => "m1", "labelIds" => ["../invalid"]}
        ] do
      Req.Test.stub(__MODULE__, &Req.Test.json(&1, body))
      assert {:error, :provider_unavailable} = HistoryProvider.message(@config, "t", "m1")
    end
  end

  test "rejects malformed responses, looping pages and unsafe inputs" do
    for body <- [
          %{},
          %{"historyId" => "bad"},
          %{"historyId" => "100", "history" => nil},
          %{"historyId" => "100", "history" => [%{"id" => "99", "messages" => [nil]}]},
          %{"historyId" => "100", "nextPageToken" => "same"}
        ] do
      Req.Test.stub(__MODULE__, &Req.Test.json(&1, body))
      assert {:error, _} = HistoryProvider.changes(@config, "t", "90", ["m1"])
    end

    Req.Test.stub(__MODULE__, fn _ -> flunk("unsafe input reached provider") end)
    assert {:error, :fixture_mismatch} = HistoryProvider.message(@config, "t", "../secret")
    assert {:error, :fixture_mismatch} = HistoryProvider.changes(@config, "t", "x", ["m1"])
  end
end
