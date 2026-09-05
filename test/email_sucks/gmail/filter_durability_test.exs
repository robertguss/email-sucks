defmodule EmailSucks.Gmail.FilterDurabilityTest do
  use ExUnit.Case, async: false
  alias Ecto.Adapters.SQL.Sandbox
  alias EmailSucks.{Repo, Gmail.FilterExperiment}

  setup do
    :ok = Sandbox.checkout(Repo, sandbox: false)

    on_exit(fn ->
      Sandbox.checkout(Repo, sandbox: false)
      Repo.delete_all(FilterExperiment, log: false)
      Sandbox.checkin(Repo)
    end)

    :ok
  end

  test "accepted filter creation survives killed request and prevents competing cleanup" do
    c = [allowed_email: "owner@gmail.com", http_options: [plug: {Req.Test, __MODULE__}]]
    {:ok, provider} = Agent.start_link(fn -> %{filters: [], creates: 0, label: nil} end)
    parent = self()

    Req.Test.stub(__MODULE__, fn conn ->
      case {conn.method, conn.request_path} do
        {"GET", "/gmail/v1/users/me/messages"} ->
          Req.Test.json(conn, %{})

        {"GET", "/gmail/v1/users/me/labels"} ->
          Req.Test.json(conn, %{"labels" => List.wrap(Agent.get(provider, & &1.label))})

        {"POST", "/gmail/v1/users/me/labels"} ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          label = Map.put(Jason.decode!(body), "id", "Label_durable")
          Agent.update(provider, &%{&1 | label: label})
          Req.Test.json(conn, label)

        {"GET", "/gmail/v1/users/me/settings/filters"} ->
          Req.Test.json(conn, %{"filter" => Agent.get(provider, & &1.filters)})

        {"POST", "/gmail/v1/users/me/settings/filters"} ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)

          filter =
            Agent.get_and_update(provider, fn s ->
              f = Map.put(Jason.decode!(body), "id", "owned#{s.creates + 1}")
              {f, %{s | filters: s.filters ++ [f], creates: s.creates + 1}}
            end)

          if filter["id"] == "owned1" do
            send(parent, :filter_accepted)

            receive do
              :never -> :ok
            end
          end

          Req.Test.json(conn, filter)

        {"DELETE", "/gmail/v1/users/me/settings/filters/" <> id} ->
          Agent.update(
            provider,
            &%{&1 | filters: Enum.reject(&1.filters, fn f -> f["id"] == id end)}
          )

          Req.Test.json(conn, %{})
      end
    end)

    {pid, monitor} =
      spawn_monitor(fn ->
        :ok = Sandbox.checkout(Repo, sandbox: false)

        receive do
          :start -> FilterExperiment.run(c, "test", "activate")
        end
      end)

    Req.Test.allow(__MODULE__, self(), pid)
    send(pid, :start)
    assert_receive :filter_accepted, 3000

    assert Repo.get!(FilterExperiment, "primary", log: false).entries["trash"]["state"] ==
             "creating"

    assert {:error, :operation_in_progress} = FilterExperiment.run(c, "test", "disable")
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^pid, :killed}

    result =
      Enum.reduce_while(1..100, nil, fn _, _ ->
        case FilterExperiment.run(c, "test", "recover") do
          {:error, :operation_in_progress} ->
            Process.sleep(10)
            {:cont, nil}

          result ->
            {:halt, result}
        end
      end)

    assert {:ok, %{state: "active", filters: 2}} = result
    assert Agent.get(provider, & &1.creates) == 2
    assert :ok = FilterExperiment.restore_for_disconnect(c, "test")
    assert Agent.get(provider, & &1.filters) == []
  end
end
