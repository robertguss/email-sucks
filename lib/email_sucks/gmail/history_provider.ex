defmodule EmailSucks.Gmail.HistoryProvider do
  @moduledoc "GET-only, bounded history and minimal metadata transport."
  @base "https://gmail.googleapis.com/gmail/v1/users/me/"
  @history_fields "history(id,messages/id,messagesAdded/message/id,messagesDeleted/message/id,labelsAdded/message/id,labelsRemoved/message/id),nextPageToken,historyId"

  def valid_id?(id),
    do: is_binary(id) and byte_size(id) in 1..256 and Regex.match?(~r/\A[a-zA-Z0-9_-]+\z/, id)

  defp cursor?(id),
    do: is_binary(id) and byte_size(id) in 1..128 and Regex.match?(~r/\A[0-9]+\z/, id)

  def profile(config, token) do
    with {:ok, %{"historyId" => cursor}} <- get(config, token, "profile", fields: "historyId"),
         true <- cursor?(cursor) do
      {:ok, cursor}
    else
      {:error, _} = error -> error
      _ -> {:error, :provider_unavailable}
    end
  end

  def message(config, token, id) do
    if valid_id?(id) do
      case get(config, token, "messages/" <> id, format: "minimal", fields: "id,labelIds") do
        {:ok, %{"id" => ^id} = body} ->
          labels = Map.get(body, "labelIds", [])

          if is_list(labels) and Enum.all?(labels, &valid_id?/1),
            do: {:ok, %{"available" => true, "labels" => Enum.sort(Enum.uniq(labels))}},
            else: {:error, :provider_unavailable}

        {:error, :not_found} ->
          {:ok, %{"available" => false}}

        {:error, _} = error ->
          error

        _ ->
          {:error, :provider_unavailable}
      end
    else
      {:error, :fixture_mismatch}
    end
  end

  def changes(config, token, cursor, members) do
    if cursor?(cursor) and is_list(members) and length(members) in 1..4 and
         Enum.all?(members, &valid_id?/1) do
      page(config, token, cursor, MapSet.new(members), nil, MapSet.new(), MapSet.new(), 1)
    else
      {:error, :fixture_mismatch}
    end
  end

  defp page(config, token, cursor, members, next, seen, affected, count) do
    params = [startHistoryId: cursor, maxResults: 100, fields: @history_fields]
    params = if next, do: Keyword.put(params, :pageToken, next), else: params

    with {:ok, body} <- get(config, token, "history", params),
         true <- cursor?(body["historyId"]),
         rows when is_list(rows) and length(rows) <= 100 <- Map.get(body, "history", []),
         {:ok, ids} <- history_ids(rows, members),
         {:ok, next} <- next_page(body) do
      affected = MapSet.union(affected, ids)

      cond do
        is_nil(next) ->
          {:ok, Enum.sort(affected), body["historyId"]}

        MapSet.member?(seen, next) ->
          {:error, :provider_unavailable}

        count >= 20 ->
          {:error, :history_limit_exceeded}

        true ->
          page(config, token, cursor, members, next, MapSet.put(seen, next), affected, count + 1)
      end
    else
      {:error, :not_found} -> {:error, :history_expired}
      {:error, _} = error -> error
      _ -> {:error, :provider_unavailable}
    end
  end

  defp history_ids(rows, members) do
    Enum.reduce_while(rows, {:ok, MapSet.new()}, fn row, {:ok, ids} ->
      case history_row_ids(row, members) do
        {:ok, row_ids} -> {:cont, {:ok, MapSet.union(ids, row_ids)}}
        error -> {:halt, error}
      end
    end)
  end

  defp history_row_ids(row, members) do
    with true <- is_map(row) and cursor?(row["id"]),
         direct when is_list(direct) <- Map.get(row, "messages", []),
         changes =
           Enum.map(
             ["messagesAdded", "messagesDeleted", "labelsAdded", "labelsRemoved"],
             &Map.get(row, &1, [])
           ),
         true <- Enum.all?(changes, &is_list/1),
         wrapped = Enum.concat(changes),
         true <- Enum.all?(wrapped, &(is_map(&1) and is_map(&1["message"]))),
         messages = direct ++ Enum.map(wrapped, & &1["message"]),
         true <-
           length(messages) <= 5000 and Enum.all?(messages, &(is_map(&1) and valid_id?(&1["id"]))) do
      ids =
        Enum.reduce(messages, MapSet.new(), fn message, ids ->
          if MapSet.member?(members, message["id"]), do: MapSet.put(ids, message["id"]), else: ids
        end)

      {:ok, ids}
    else
      _ -> {:error, :provider_unavailable}
    end
  end

  defp next_page(body) do
    case Map.fetch(body, "nextPageToken") do
      :error -> {:ok, nil}
      {:ok, value} when is_binary(value) and byte_size(value) in 1..4096 -> {:ok, value}
      _ -> {:error, :provider_unavailable}
    end
  end

  defp get(config, token, path, params) do
    options =
      Keyword.merge(
        [receive_timeout: 10_000, connect_options: [timeout: 5_000]],
        Keyword.get(config, :http_options, [])
      )

    options =
      Keyword.merge(options,
        method: :get,
        url: @base <> path <> "?" <> URI.encode_query(params),
        retry: false,
        redirect: false,
        headers: [{"authorization", "Bearer " <> token}]
      )

    case Req.request(options) do
      {:ok, %{status: 200, body: body}} when is_map(body) -> {:ok, body}
      {:ok, %{status: 401}} -> {:error, :reconnect_required}
      {:ok, %{status: 403, body: body}} -> forbidden(body)
      {:ok, %{status: 404}} -> {:error, :not_found}
      _ -> {:error, :provider_unavailable}
    end
  end

  defp forbidden(%{"error" => error}) when is_map(error) do
    reasons =
      for row <- List.wrap(error["details"]) ++ List.wrap(error["errors"]),
          is_map(row),
          do: row["reason"]

    cond do
      Enum.any?(reasons, &(&1 in ["SERVICE_DISABLED", "accessNotConfigured"])) ->
        {:error, :api_disabled}

      Enum.any?(reasons, &(&1 in ["ACCESS_TOKEN_SCOPE_INSUFFICIENT", "insufficientPermissions"])) ->
        {:error, :missing_scope}

      true ->
        {:error, :permission_denied}
    end
  end

  defp forbidden(_), do: {:error, :permission_denied}
end
