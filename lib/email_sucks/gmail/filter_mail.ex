defmodule EmailSucks.Gmail.FilterMail do
  @moduledoc "Bounded metadata and label boundary for the controlled filter experiment."
  @base "https://gmail.googleapis.com/gmail/v1/users/me/"
  @sender "robertguss@gmail.com"
  @subject "phase0-filter-trash-001"

  def empty?(config, token) do
    with {:ok, ids} <- list(config, token, q: query(config)) do
      if ids == [], do: :ok, else: {:error, :fixture_mismatch}
    end
  end

  def label(config, token, nonce) do
    if valid_nonce?(nonce) do
      name = "Postman/Filter-probe-" <> nonce

      with {:ok, body} <- get(config, token, "labels", fields: "labels(id,name)"),
           rows when is_list(rows) <- Map.get(body, "labels"),
           true <-
             Enum.all?(rows, &(is_map(&1) and valid_id?(&1["id"]) and is_binary(&1["name"]))) do
        case Enum.filter(rows, &(&1["name"] == name)) do
          [%{"id" => id}] -> {:ok, id}
          [] -> create_label(config, token, name)
          _ -> {:error, :fixture_mismatch}
        end
      else
        {:error, _} = error -> error
        _ -> {:error, :provider_unavailable}
      end
    else
      {:error, :fixture_mismatch}
    end
  end

  def messages(config, token, nonce) do
    if valid_nonce?(nonce) do
      read_messages(config, token, q: query(config) <> ~s( "postman-probe-#{nonce}"))
    else
      {:error, :fixture_mismatch}
    end
  end

  def held_messages(config, token, label_id) do
    if valid_id?(label_id) do
      with {:ok, messages} <- read_messages(config, token, labelIds: label_id) do
        if Enum.all?(messages, &(label_id in &1["labelIds"])),
          do: {:ok, messages},
          else: {:error, :fixture_mismatch}
      end
    else
      {:error, :fixture_mismatch}
    end
  end

  defp query(config), do: "from:#{@sender} to:#{config[:allowed_email]} subject:#{@subject}"

  defp create_label(config, token, name) do
    # An uncertain create is returned as a failure. Every retry resolves this exact name first.
    with {:ok, %{"id" => id}} <-
           api(config, token, method: :post, url: @base <> "labels", json: %{name: name}),
         true <- valid_id?(id) do
      {:ok, id}
    else
      {:error, _} = error -> error
      _ -> {:error, :provider_unavailable}
    end
  end

  defp read_messages(config, token, params) do
    with {:ok, ids} <- list(config, token, params) do
      Enum.reduce_while(ids, {:ok, []}, fn id, {:ok, messages} ->
        case metadata(config, token, id) do
          {:ok, message} -> {:cont, {:ok, [message | messages]}}
          error -> {:halt, error}
        end
      end)
      |> case do
        {:ok, messages} -> {:ok, Enum.reverse(messages)}
        error -> error
      end
    end
  end

  defp list(config, token, params),
    do:
      page(
        config,
        token,
        params ++
          [
            includeSpamTrash: true,
            maxResults: 100,
            fields: "messages/id,nextPageToken,resultSizeEstimate"
          ],
        nil,
        MapSet.new(),
        MapSet.new(),
        []
      )

  defp page(config, token, params, cursor, seen_pages, seen_ids, pages) do
    params = if cursor, do: Keyword.put(params, :pageToken, cursor), else: params

    with {:ok, body} <- get(config, token, "messages", params),
         rows when is_list(rows) <- Map.get(body, "messages", []),
         true <- Enum.all?(rows, &(is_map(&1) and valid_id?(&1["id"]))),
         ids = Enum.map(rows, & &1["id"]),
         true <- length(ids) == MapSet.size(MapSet.new(ids)),
         true <- Enum.all?(ids, &(not MapSet.member?(seen_ids, &1))),
         true <- valid_estimate?(body, ids),
         {:ok, next} <- next_page(body) do
      pages = [ids | pages]

      cond do
        is_nil(next) ->
          {:ok, pages |> Enum.reverse() |> List.flatten()}

        MapSet.member?(seen_pages, next) or MapSet.size(seen_pages) >= 100 ->
          {:error, :provider_unavailable}

        true ->
          page(
            config,
            token,
            params,
            next,
            MapSet.put(seen_pages, next),
            MapSet.union(seen_ids, MapSet.new(ids)),
            pages
          )
      end
    else
      {:error, _} = error -> error
      _ -> {:error, :provider_unavailable}
    end
  end

  defp valid_estimate?(body, ids) do
    case Map.fetch(body, "resultSizeEstimate") do
      :error ->
        true

      {:ok, count} when is_integer(count) and count >= 0 ->
        ids != [] or count == 0 or Map.has_key?(body, "nextPageToken")

      _ ->
        false
    end
  end

  defp next_page(body) do
    case Map.fetch(body, "nextPageToken") do
      :error ->
        {:ok, nil}

      {:ok, token} when is_binary(token) and byte_size(token) > 0 and byte_size(token) <= 4096 ->
        {:ok, token}

      _ ->
        {:error, :provider_unavailable}
    end
  end

  defp metadata(config, token, id) do
    with {:ok, body} <-
           get(config, token, "messages/" <> id,
             format: "metadata",
             metadataHeaders: "From",
             metadataHeaders: "To",
             metadataHeaders: "Subject",
             fields: "id,labelIds,payload/headers"
           ),
         %{"id" => ^id, "labelIds" => labels, "payload" => %{"headers" => headers}} <- body,
         true <- is_list(labels) and Enum.all?(labels, &valid_id?/1),
         true <- is_list(headers) and Enum.all?(headers, &valid_header?/1),
         true <- header(headers, "subject") == @subject,
         true <- mailbox?(header(headers, "from"), @sender),
         true <- mailbox?(header(headers, "to"), config[:allowed_email]) do
      # Never return unexpected provider fields such as snippets or message bodies.
      {:ok, %{"id" => id, "labelIds" => labels, "payload" => %{"headers" => headers}}}
    else
      {:error, _} = error -> error
      _ -> {:error, :fixture_mismatch}
    end
  end

  defp valid_header?(%{"name" => name, "value" => value})
       when is_binary(name) and is_binary(value),
       do: String.downcase(name) in ["from", "to", "subject"]

  defp valid_header?(_), do: false

  defp header(headers, name) do
    case Enum.filter(headers, &(String.downcase(&1["name"]) == name)) do
      [%{"value" => value}] -> String.trim(value)
      _ -> nil
    end
  end

  defp mailbox?(value, expected) when is_binary(value) and is_binary(expected) do
    value = String.downcase(value)
    value == expected or Regex.match?(~r/\A[^<>,]*<#{Regex.escape(expected)}>\z/, value)
  end

  defp mailbox?(_, _), do: false

  defp valid_id?(id), do: is_binary(id) and Regex.match?(~r/\A[a-zA-Z0-9_-]+\z/, id)
  defp valid_nonce?(nonce), do: is_binary(nonce) and Regex.match?(~r/\A[0-9a-f]{32}\z/, nonce)

  defp get(config, token, path, params),
    do: api(config, token, method: :get, url: @base <> path <> "?" <> URI.encode_query(params))

  defp api(config, token, opts) do
    options =
      Keyword.merge(
        [receive_timeout: 10_000, connect_options: [timeout: 5_000]],
        Keyword.get(config, :http_options, [])
      )

    options =
      options
      |> Keyword.merge(opts)
      |> Keyword.merge(
        retry: false,
        redirect: false,
        headers: [{"authorization", "Bearer " <> token}]
      )

    case Req.request(options) do
      {:ok, %{status: status, body: body}} when status in [200, 201] and is_map(body) ->
        {:ok, body}

      {:ok, %{status: 401}} ->
        {:error, :reconnect_required}

      {:ok, %{status: 403, body: body}} ->
        forbidden(body)

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      _ ->
        {:error, :provider_unavailable}
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
