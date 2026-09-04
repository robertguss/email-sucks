defmodule EmailSucks.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      EmailSucksWeb.Telemetry,
      EmailSucks.Repo,
      {Oban, Application.fetch_env!(:email_sucks, Oban)},
      {DNSCluster, query: Application.get_env(:email_sucks, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: EmailSucks.PubSub},
      # Start a worker by calling: EmailSucks.Worker.start_link(arg)
      # {EmailSucks.Worker, arg},
      # Start to serve requests, typically the last entry
      EmailSucksWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EmailSucks.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EmailSucksWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
