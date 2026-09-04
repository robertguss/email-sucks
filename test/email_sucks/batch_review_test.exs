defmodule EmailSucks.BatchReviewTest do
  use EmailSucks.DataCase
  alias EmailSucks.PhaseZero
  alias EmailSucks.PhaseZero.{BatchReview, ReleaseJournal}

  defp release(snapshot, ids) do
    for id <- ids do
      {:ok, %{message_id: ^id, token: token}} = ReleaseJournal.claim(snapshot.id, 100)
      {:ok, :recorded} = ReleaseJournal.record(snapshot.id, id, token, :released)
    end
  end

  test "review is per batch, not permanent conversation state" do
    account = Ecto.UUID.generate()
    {:ok, first} = PhaseZero.freeze(account, ["a"])
    assert {:ok, :prepared} = BatchReview.prepare(first.id, %{"thread" => ["a"]})
    release(first, ["a"])
    assert {:ok, :reviewed} = BatchReview.review(first.id, "thread")
    assert {:ok, %{caught_up?: true}} = BatchReview.status(account)
    first |> Ash.Changeset.for_update(:verify) |> Ash.update!(authorize?: false)
    {:ok, second} = PhaseZero.freeze(account, ["b"])
    {:ok, :prepared} = BatchReview.prepare(second.id, %{"thread" => ["b"]})
    release(second, ["b"])
    assert {:ok, %{unreviewed: 1, reviewed: 1, caught_up?: false}} = BatchReview.status(account)
    assert {:ok, :reviewed} = BatchReview.review(first.id, "thread")
    assert {:ok, %{unreviewed: 1}} = BatchReview.status(account)
  end

  test "held or partially released conversation cannot be acknowledged" do
    account = Ecto.UUID.generate()
    {:ok, batch} = PhaseZero.freeze(account, ["a", "b"])
    {:ok, :prepared} = BatchReview.prepare(batch.id, %{"thread" => ["a", "b"]})
    release(batch, ["a"])
    assert {:error, :not_released} = BatchReview.review(batch.id, "thread")

    assert {:ok, %{pending: 1, unreviewed: 0, delivery_pending?: true}} =
             BatchReview.status(account)

    release(batch, ["b"])
    assert {:ok, %{unreviewed: 1, pending: 0}} = BatchReview.status(account)
  end

  test "grouping is a frozen exact partition and replay does not erase reviews" do
    {:ok, batch} = PhaseZero.freeze(Ecto.UUID.generate(), ["a", "b"])
    assert {:error, :invalid_membership} = BatchReview.prepare(batch.id, %{"t" => ["a", "late"]})

    assert {:error, :invalid_membership} =
             BatchReview.prepare(batch.id, %{"t" => ["a", "a", "b"]})

    groups = %{"t" => ["b", "a"]}
    {:ok, :prepared} = BatchReview.prepare(batch.id, groups)
    release(batch, ["a", "b"])
    {:ok, :reviewed} = BatchReview.review(batch.id, "t")
    assert {:ok, :prepared} = BatchReview.prepare(batch.id, %{"t" => ["a", "b"]})
    assert {:error, :membership_frozen} = BatchReview.prepare(batch.id, %{"other" => ["a", "b"]})
    assert {:ok, %{reviewed: 1}} = BatchReview.status(batch.account_key)
  end

  test "missing preparation is explicit, not mistaken for an empty mailbox" do
    {:ok, batch} = PhaseZero.freeze(Ecto.UUID.generate(), ["a"])
    assert {:error, :unprepared_batch} = BatchReview.status(batch.account_key)
    assert {:error, :unprepared_batch} = BatchReview.review(batch.id, "t")
  end

  test "empty prepared delivery is caught up without a review or notification" do
    {:ok, batch} = PhaseZero.freeze(Ecto.UUID.generate(), [])
    {:ok, :prepared} = BatchReview.prepare(batch.id, %{})

    assert {:ok, %{caught_up?: true, delivery_pending?: false}} =
             BatchReview.status(batch.account_key)

    assert {:error, :item_not_found} = BatchReview.review(batch.id, "missing")
  end
end
