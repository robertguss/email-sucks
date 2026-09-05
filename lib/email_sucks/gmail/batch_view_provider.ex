defmodule EmailSucks.Gmail.BatchViewProvider do
  @moduledoc "Exact-message, GET-only metadata for the saved batch."
  alias EmailSucks.Gmail.HistoryProvider
  @base "https://gmail.googleapis.com/gmail/v1/users/me/messages/"

  def message(config, token, id) do
    if HistoryProvider.valid_id?(id) do
      options =
        Keyword.merge(
          [receive_timeout: 10_000, connect_options: [timeout: 5_000]],
          Keyword.get(config, :http_options, [])
        )

      params =
        URI.encode_query(
          format: "metadata",
          metadataHeaders: "From",
          metadataHeaders: "Subject",
          fields: "id,threadId,labelIds,snippet,internalDate,payload/headers"
        )

      options =
        Keyword.merge(options,
          method: :get,
          url: @base <> id <> "?" <> params,
          retry: false,
          redirect: false,
          headers: [{"authorization", "Bearer " <> token}]
        )

      case Req.request(options) do
        {:ok, %{status: 200, body: body}} -> validate(body, id)
        {:ok, %{status: 404}} -> {:ok, nil}
        {:ok, %{status: 401}} -> {:error, :reconnect_required}
        {:ok, %{status: 403, body: body}} -> forbidden(body)
        _ -> {:error, :provider_unavailable}
      end
    else
      {:error, :fixture_mismatch}
    end
  end

  defp forbidden(%{"error" => error}) when is_map(error) do
    reasons =
      for row <- List.wrap(error["details"]) ++ List.wrap(error["errors"]),
          is_map(row),
          do: row["reason"]

    if Enum.any?(
         reasons,
         &(&1 in ["ACCESS_TOKEN_SCOPE_INSUFFICIENT", "insufficientPermissions"])
       ), do: {:error, :missing_scope}, else: {:error, :provider_unavailable}
  end

  defp forbidden(_), do: {:error, :provider_unavailable}

  defp validate(
         %{
           "id" => id,
           "threadId" => thread,
           "labelIds" => labels,
           "payload" => %{"headers" => headers}
         } = body,
         id
       ) do
    if HistoryProvider.valid_id?(thread) and is_list(labels) and
         Enum.all?(labels, &HistoryProvider.valid_id?/1) and
         is_list(headers) and
         Enum.all?(headers, &(is_map(&1) and is_binary(&1["name"]) and is_binary(&1["value"]))) and
         is_binary(Map.get(body, "snippet", "")) do
      {:ok,
       %{
         thread: thread,
         labels: labels,
         subject: header(headers, "subject", "(No subject)"),
         sender: header(headers, "from", "Unknown sender"),
         preview: String.slice(Map.get(body, "snippet", ""), 0, 1000),
         received_at: received_at(body["internalDate"])
       }}
    else
      {:error, :provider_unavailable}
    end
  end

  defp validate(_, _), do: {:error, :provider_unavailable}

  defp header(headers, name, default) do
    case Enum.find(headers, &(String.downcase(&1["name"]) == name)) do
      nil -> default
      row -> String.slice(row["value"], 0, 1000)
    end
  end

  defp received_at(value) when is_binary(value) do
    with {milliseconds, ""} <- Integer.parse(value),
         {:ok, datetime} <- DateTime.from_unix(milliseconds, :millisecond),
         do: DateTime.to_iso8601(datetime),
         else: (_ -> nil)
  end

  defp received_at(_), do: nil
end
