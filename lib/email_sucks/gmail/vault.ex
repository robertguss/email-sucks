defmodule EmailSucks.Gmail.Vault do
  @moduledoc "Authenticated encryption with a key independent of the browser session secret."
  def seal(value, purpose), do: Phoenix.Token.encrypt(key(), purpose, value)

  def open(ciphertext, purpose) do
    case Phoenix.Token.decrypt(key(), purpose, ciphertext, max_age: :infinity) do
      {:ok, value} -> {:ok, value}
      _ -> {:error, :invalid_ciphertext}
    end
  end

  defp key, do: Application.fetch_env!(:email_sucks, :gmail) |> Keyword.fetch!(:vault_key)
end
