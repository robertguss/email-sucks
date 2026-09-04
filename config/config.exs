# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :email_sucks,
  ecto_repos: [EmailSucks.Repo],
  ash_domains: [EmailSucks.PhaseZero],
  generators: [timestamp_type: :utc_datetime]

config :email_sucks, Oban, repo: EmailSucks.Repo, queues: false, plugins: false

config :inertia,
  endpoint: EmailSucksWeb.Endpoint,
  static_paths: ["/assets/app.js"],
  history: [encrypt: true]

# Configure the endpoint
config :email_sucks, EmailSucksWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: EmailSucksWeb.ErrorHTML, json: EmailSucksWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: EmailSucks.PubSub,
  live_view: [signing_salt: "xjdGrUYT"]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :phoenix, :filter_parameters, [
  "password",
  "secret",
  "token",
  "code",
  "state",
  "credential"
]

# Environment-specific configuration overrides the defaults above.
import_config "#{config_env()}.exs"
