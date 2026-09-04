defmodule EmailSucks.WorkflowContractTest do
  use ExUnit.Case, async: true
  alias EmailSucks.PhaseZero.WorkItem

  test "This Week anchors Friday and never silently rolls overdue work forward" do
    friday = WorkItem.open(:this_week, ~D[2026-09-04])
    assert friday.due_on == ~D[2026-09-04]
    refute WorkItem.overdue?(friday, ~D[2026-09-04])
    assert WorkItem.overdue?(friday, ~D[2026-09-05])
    assert WorkItem.overdue?(friday, ~D[2026-09-07])
    assert WorkItem.open(:this_week, ~D[2026-09-05]).due_on == ~D[2026-09-11]
    assert WorkItem.open(:this_week, ~D[2026-09-06]).due_on == ~D[2026-09-11]
  end

  test "Today uses local calendar boundaries and Whenever has no due date" do
    today = WorkItem.open(:today, ~D[2026-09-04])
    refute WorkItem.overdue?(today, ~D[2026-09-04])
    assert WorkItem.overdue?(today, ~D[2026-09-05])
    whenever = WorkItem.open(:whenever, ~D[2026-09-04])
    assert whenever.due_on == nil
    refute WorkItem.overdue?(whenever, ~D[2030-01-01])
  end

  test "held human reply and visible automated reply preserve Waiting" do
    waiting = WorkItem.open(:today, ~D[2026-09-04]) |> WorkItem.wait(~D[2026-09-04])
    assert waiting.horizon == nil
    assert waiting.due_on == nil
    assert waiting.waiting_since == ~D[2026-09-04]
    assert WorkItem.reply(waiting, :held, :human, ~D[2026-09-05]) == waiting
    assert WorkItem.reply(waiting, :released, :automated, ~D[2026-09-05]) == waiting
  end

  test "visible human reply reopens Waiting with a fresh week commitment" do
    waiting = WorkItem.open(:today, ~D[2026-09-04]) |> WorkItem.wait(~D[2026-09-04])

    for delivery <- [:released, :bypassed] do
      reopened = WorkItem.reply(waiting, delivery, :human, ~D[2026-09-05])
      assert reopened.status == :open
      assert reopened.horizon == :this_week
      assert reopened.due_on == ~D[2026-09-11]
      assert reopened.waiting_since == nil
      assert WorkItem.reply(reopened, delivery, :human, ~D[2026-09-12]) == reopened
    end
  end

  test "failed or unknown sending cannot apply a disposition" do
    item = WorkItem.open(:today, ~D[2026-09-04])

    for outcome <- [:failed, :unknown, :pending], disposition <- [:done, :waiting, :keep_open] do
      assert WorkItem.after_send(item, outcome, disposition, ~D[2026-09-05]) ==
               {:error, :send_not_confirmed}
    end

    assert {:ok, ^item} = WorkItem.after_send(item, :confirmed, :keep_open, ~D[2026-09-05])
    assert {:ok, done} = WorkItem.after_send(item, :confirmed, :done, ~D[2026-09-05])
    assert done.status == :resolved
    assert done.horizon == nil
    assert done.due_on == nil
  end
end
