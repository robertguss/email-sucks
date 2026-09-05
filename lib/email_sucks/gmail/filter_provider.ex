defmodule EmailSucks.Gmail.FilterProvider do
  @moduledoc "Bounded Phase 0 filter HTTP boundary. The caller owns durable intent and cleanup."
  alias EmailSucks.Gmail.FilterProfile
  @endpoint "https://gmail.googleapis.com/gmail/v1/users/me/settings/filters"

  def list(config, token) do
    case request(config, token, method: :get, url: @endpoint) do
      {:ok, %{status: 200, body: body}} when body == %{} ->
        {:ok, []}

      {:ok, %{status: 200, body: %{"filter" => rows} = body}} when is_list(rows) ->
        if map_size(body) == 1 and Enum.all?(rows, &valid_filter?/1) and
             length(Enum.uniq_by(rows, & &1["id"])) == length(rows),
           do: {:ok, rows},
           else: {:error, :provider_unavailable}

      response ->
        error(response)
    end
  end

  def create(config, token, specification, profile \\ "primary") do
    if FilterProfile.known?(profile) and experiment?(config, specification, profile) do
      case request(config, token, method: :post, url: @endpoint, json: specification) do
        {:ok, %{status: status, body: body}} when status in [200, 201] ->
          if valid_filter?(body) and Map.delete(body, "id") == specification,
            do: {:ok, body},
            else: {:error, :provider_unavailable}

        response ->
          error(response)
      end
    else
      {:error, :fixture_mismatch}
    end
  end

  @doc "Deletes a saved owned ID. The caller must verify ownership before invoking this boundary."
  def delete(config, token, id) do
    if valid_id?(id) do
      case request(config, token, method: :delete, url: @endpoint <> "/" <> id) do
        {:ok, %{status: status}} when status in [200, 204, 404] -> :ok
        response -> error(response)
      end
    else
      {:error, :fixture_mismatch}
    end
  end

  defp experiment?(config, %{"criteria" => criteria, "action" => action} = specification, profile)
       when is_map(criteria) do
    email = config[:allowed_email]
    marker = criteria["query"]
    label = config[:filter_lab_label_id]

    expected = %{
      "from" => "robertguss@gmail.com",
      "to" => email,
      "subject" => FilterProfile.subject(profile),
      "query" => marker
    }

    trash? = profile == "primary" and action == %{"addLabelIds" => ["TRASH"]}

    hold? =
      is_binary(label) and Regex.match?(~r/\ALabel_[a-zA-Z0-9_-]+\z/, label) and
        action == %{"addLabelIds" => [label], "removeLabelIds" => ["INBOX"]}

    map_size(specification) == 2 and is_binary(email) and String.contains?(email, "@") and
      is_binary(marker) and Regex.match?(~r/\A"postman-probe-[0-9a-f]{32}"\z/, marker) and
      criteria == expected and (trash? or hold?)
  end

  defp experiment?(_, _, _), do: false

  defp valid_filter?(%{"id" => id, "criteria" => criteria, "action" => action} = row) do
    map_size(row) == 3 and valid_id?(id) and is_map(criteria) and is_map(action) and
      Enum.all?(criteria, &valid_criterion?/1) and Enum.all?(action, &valid_action?/1)
  end

  defp valid_filter?(_), do: false

  # Preserve complete typed provider criteria; never infer ownership from a label alone.
  defp valid_criterion?({key, value})
       when key in ~w(from to subject query negatedQuery),
       do: is_binary(value)

  defp valid_criterion?({key, value}) when key in ~w(hasAttachment excludeChats),
    do: is_boolean(value)

  defp valid_criterion?({"size", value}), do: is_integer(value) and value >= 0

  defp valid_criterion?({"sizeComparison", value}),
    do: value in ~w(unspecified smaller larger)

  defp valid_criterion?(_), do: false

  defp valid_action?({key, ids}) when key in ~w(addLabelIds removeLabelIds),
    do: is_list(ids) and Enum.all?(ids, &valid_id?/1)

  defp valid_action?({"forward", address}), do: is_binary(address)
  defp valid_action?(_), do: false

  defp valid_id?(id), do: is_binary(id) and Regex.match?(~r/\A[a-zA-Z0-9_-]+\z/, id)

  defp request(config, token, opts) do
    if is_binary(token) and Regex.match?(~r/\A[!-~]+\z/, token) do
      config
      |> Keyword.get(:http_options, [])
      |> Keyword.put_new(:receive_timeout, 10_000)
      |> Keyword.put_new(:connect_options, timeout: 5_000)
      |> Keyword.merge(opts)
      |> Keyword.merge(
        retry: false,
        redirect: false,
        headers: [{"authorization", "Bearer " <> token}]
      )
      |> Req.request()
    else
      {:error, :reconnect_required}
    end
  end

  defp error({:ok, %{status: 401}}), do: {:error, :reconnect_required}

  defp error({:ok, %{status: 403, body: %{"error" => body}}}) when is_map(body) do
    reasons =
      for row <- List.wrap(body["details"]) ++ List.wrap(body["errors"]),
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

  defp error({:ok, %{status: 403}}), do: {:error, :permission_denied}
  defp error({:error, :reconnect_required}), do: {:error, :reconnect_required}
  defp error(_), do: {:error, :provider_unavailable}
end
