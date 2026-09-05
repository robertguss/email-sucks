defmodule EmailSucks.Gmail.FilterProfile do
  @moduledoc "Closed, immutable fixture definitions; arbitrary filter specifications are never accepted."
  def ids, do: ["primary", "arrival-primary-v1"]
  def known?(id), do: id in ids()
  def subject("primary"), do: "phase0-filter-trash-001"
  def subject("arrival-primary-v1"), do: "phase0-filter-arrival-001"
  def keys("primary"), do: ~w(trash hold)
  def keys("arrival-primary-v1"), do: ~w(hold)

  def specifications(profile, email, nonce, label) do
    criteria = %{
      "from" => "robertguss@gmail.com",
      "to" => email,
      "subject" => subject(profile),
      "query" => "\"postman-probe-#{nonce}\""
    }

    Map.new(keys(profile), fn key ->
      action =
        case key do
          "trash" -> %{"addLabelIds" => ["TRASH"]}
          "hold" -> %{"addLabelIds" => [label], "removeLabelIds" => ["INBOX"]}
        end

      {key, %{"criteria" => criteria, "action" => action}}
    end)
  end
end
