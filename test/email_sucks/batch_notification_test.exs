defmodule EmailSucks.BatchNotificationTest do
  use EmailSucks.DataCase
  alias EmailSucks.PhaseZero
  alias EmailSucks.PhaseZero.{BatchNotification, BatchReview, ReleaseJournal}

  defp batch do
    {:ok, snapshot} = PhaseZero.freeze(Ecto.UUID.generate(), ["a", "b"])
    {:ok, :prepared} = BatchReview.prepare(snapshot.id, %{"thread" => ["a", "b"]})
    snapshot
  end

  defp release(snapshot) do
    for _ <- 1..2 do
      {:ok, %{message_id: id, token: token}} = ReleaseJournal.claim(snapshot.id, 100)
      {:ok, :recorded} = ReleaseJournal.record(snapshot.id, id, token, :released)
    end
  end

  test "one notification uses distinct conversations and replay does not deliver again" do
    snapshot = batch()
    release(snapshot)

    assert {:ok, :sent} =
             BatchNotification.deliver(snapshot.id, true, fn payload ->
               refute Repo.in_transaction?()
               assert payload == %{batch_id: snapshot.id, conversation_count: 1}
               :ok
             end)

    assert {:ok, :sent} =
             BatchNotification.deliver(snapshot.id, true, fn _ -> flunk("duplicate") end)
  end

  test "lost response or crashed notifier is not blindly retried" do
    snapshot = batch()
    release(snapshot)

    assert_raise RuntimeError, "notification crash", fn ->
      BatchNotification.deliver(snapshot.id, true, fn _ -> raise "notification crash" end)
    end

    assert {:ok, :unknown} =
             BatchNotification.deliver(snapshot.id, true, fn _ -> flunk("uncertain retry") end)
  end

  test "only confirmed rejection permits another attempt" do
    snapshot = batch()
    release(snapshot)
    assert {:ok, :rejected} = BatchNotification.deliver(snapshot.id, true, fn _ -> :rejected end)
    assert {:ok, :sent} = BatchNotification.deliver(snapshot.id, true, fn _ -> :ok end)
  end

  test "incomplete, empty and disabled batches never call a notifier" do
    snapshot = batch()
    never = fn _ -> flunk("notification was not eligible") end
    assert {:error, :release_incomplete} = BatchNotification.deliver(snapshot.id, true, never)
    assert {:ok, :disabled} = BatchNotification.deliver(snapshot.id, false, never)
    {:ok, empty} = PhaseZero.freeze(Ecto.UUID.generate(), [])
    assert {:ok, :empty} = BatchNotification.deliver(empty.id, true, never)
  end
end
