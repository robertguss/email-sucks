defmodule EmailSucks.Gmail.TrialTest do
  use EmailSucks.DataCase
  alias EmailSucks.Gmail.{Trial, TrialRun}
  alias EmailSucks.Repo

  test "manual receipts preserve the future scheduled occurrence and fence after stop" do
    now = System.system_time(:second)
    Repo.insert!(%Trial{id: "primary", state: "active", next_due: now + 300})
    assert {:ok, run} = Trial.request(Ecto.UUID.generate())
    assert run.kind == "manual"
    assert Repo.get!(Trial, "primary").next_due == now + 300
    assert {:ok, same} = Trial.request(Ecto.UUID.generate())
    assert same.id == run.id
    Trial.fence()
    assert {:error, :invalid_transition} = Trial.request(Ecto.UUID.generate())
    assert Repo.get!(TrialRun, run.id).state == "planned"
  end

  test "stop can abandon starting intent before a filter journal exists" do
    Repo.insert!(%Trial{id: "primary", state: "starting"})
    assert {:ok, %{state: "stopped"}} = Trial.stop([], "unused")
    assert Repo.get(EmailSucks.Gmail.FilterExperiment, Trial.profile()) == nil
    assert {:ok, %{state: "stopped"}} = Trial.stop([], "unused")
  end
end
