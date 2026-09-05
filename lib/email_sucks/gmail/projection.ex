defmodule EmailSucks.Gmail.Projection do
  @moduledoc "Read-before-write and read-back for one frozen message's Inbox/held labels."
  alias EmailSucks.Gmail.Google

  def reconcile(config, token, id, label, held?, may_write?) do
    with {:ok, message} <- Google.controlled_message(config, token, id),
         :ok <- usable(message) do
      cond do
        matches?(message, label, held?) ->
          :ok

        not may_write? ->
          {:error, :verification_failed}

        true ->
          {add, remove} = if held?, do: {[label], ["INBOX"]}, else: {["INBOX"], [label]}

          with {:ok, _} <- Google.modify_message(config, token, id, add, remove),
               {:ok, actual} <- Google.controlled_message(config, token, id),
               :ok <- usable(actual),
               true <- matches?(actual, label, held?) do
            :ok
          else
            false -> {:error, :verification_failed}
            error -> error
          end
      end
    end
  end

  defp usable(message) do
    if Enum.any?(["TRASH", "SPAM", "DRAFT"], &(&1 in message["labelIds"])),
      do: {:error, :fixture_mismatch},
      else: :ok
  end

  defp matches?(message, label, held?) do
    label in message["labelIds"] == held? and "INBOX" in message["labelIds"] != held?
  end
end
