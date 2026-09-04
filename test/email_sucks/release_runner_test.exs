defmodule EmailSucks.ReleaseRunnerTest do
  use EmailSucks.DataCase
  alias EmailSucks.PhaseZero
  alias EmailSucks.PhaseZero.{ReleaseRunner, ReleaseJournal, Recovery}

  test "a lost response is reconciled without sending the provider write twice" do
    {:ok, snapshot} = PhaseZero.freeze(Ecto.UUID.generate(), ["a"])
    {:ok, provider} = Agent.start_link(fn -> %{state: :held, writes: 0} end)
    on_exit(fn -> if Process.alive?(provider), do: Agent.stop(provider) end)

    call = fn
      :inspect, "a" ->
        Agent.get(provider, & &1.state)

      :release, "a" ->
        Agent.update(provider, &%{&1 | state: :released, writes: &1.writes + 1})
        {:error, :lost_response}
    end

    assert {:error, :provider_unavailable} = ReleaseRunner.step(snapshot.id, call, 100)
    assert {:ok, %{unknown: 1}} = ReleaseJournal.status(snapshot.id)
    assert {:ok, :busy} = ReleaseRunner.step(snapshot.id, call, 110)
    assert {:ok, %{outcome: :released}} = ReleaseRunner.step(snapshot.id, call, 131)
    assert Agent.get(provider, & &1.writes) == 1
  end

  test "a crash before writing leaves a claim that must reconcile before another write" do
    {:ok, snapshot} = PhaseZero.freeze(Ecto.UUID.generate(), ["a"])

    assert_raise RuntimeError, "fixture crash", fn ->
      ReleaseRunner.step(snapshot.id, fn _, _ -> raise "fixture crash" end, 100)
    end

    assert {:ok, %{unknown: 1}} = ReleaseJournal.status(snapshot.id)

    assert {:ok, %{outcome: :pending}} =
             ReleaseRunner.step(snapshot.id, fn :inspect, "a" -> :held end, 131)

    call = fn
      :inspect, "a" -> :released
      :release, _ -> flunk("already-visible mail must not be changed")
    end

    assert {:ok, %{outcome: :released}} = ReleaseRunner.step(snapshot.id, call, 132)
  end

  test "normal release reads back the outcome and never holds a database transaction during provider I/O" do
    {:ok, snapshot} = PhaseZero.freeze(Ecto.UUID.generate(), ["a"])
    {:ok, provider} = Agent.start_link(fn -> :held end)
    on_exit(fn -> if Process.alive?(provider), do: Agent.stop(provider) end)

    call = fn action, "a" ->
      refute Repo.in_transaction?()

      case action do
        :inspect -> Agent.get(provider, & &1)
        :release -> Agent.update(provider, fn _ -> :released end)
      end
    end

    assert {:ok, %{outcome: :released}} = ReleaseRunner.step(snapshot.id, call, 100)
    assert {:ok, :complete} = ReleaseRunner.step(snapshot.id, call, 101)
  end

  test "unavailable source is not resurrected and recovery stops new calls" do
    account = Ecto.UUID.generate()
    {:ok, snapshot} = PhaseZero.freeze(account, ["a", "b"])

    assert {:ok, %{outcome: :unavailable}} =
             ReleaseRunner.step(snapshot.id, fn :inspect, "a" -> :unavailable end, 100)

    {:ok, :stopping} = Recovery.begin(account)

    assert {:error, :recovery_active} =
             ReleaseRunner.step(
               snapshot.id,
               fn _, _ -> flunk("recovery must stop new I/O") end,
               101
             )

    assert {:ok, %{unavailable: 1, pending: 1}} = ReleaseJournal.status(snapshot.id)
  end
end
