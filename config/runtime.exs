import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/email_sucks start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
restore_setting = System.get_env("RESTORE_MODE", "false")
if restore_setting not in ["true", "false"], do: raise("RESTORE_MODE must be true or false")
restore_mode = restore_setting == "true"
config :email_sucks, :restore_mode, restore_mode

role = System.get_env("APP_ROLE", "web")
if role not in ["web", "worker"], do: raise("APP_ROLE must be web or worker")

if config_env() != :test do
  config :email_sucks, Oban,
    queues: if(role == "worker" and not restore_mode, do: [phase_zero: 5], else: false)
end

if role == "web" and System.get_env("PHX_SERVER") in ["true", "1"] do
  config :email_sucks, EmailSucksWeb.Endpoint, server: true
end

config :email_sucks, EmailSucksWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :email_sucks, EmailSucksWeb.Endpoint,
    live_reload: [
      web_console_logger: false,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/email_sucks_web/router\.ex$"E,
        ~r"lib/email_sucks_web/(controllers|live|components)/.*\.(ex|heex)$"E
      ]
    ]
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :email_sucks, EmailSucks.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  if byte_size(secret_key_base) < 64 do
    raise "SECRET_KEY_BASE must contain at least 64 bytes of random secret material"
  end

  host = System.get_env("PHX_HOST") || System.get_env("RENDER_EXTERNAL_HOSTNAME") || "example.com"

  config :email_sucks, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :email_sucks, EmailSucksWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://bandit.hexdocs.pm/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :email_sucks, EmailSucksWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://plug.hexdocs.pm/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :email_sucks, EmailSucksWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end

# Explicit opt-in: ordinary development and all automated tests run without real credentials.
if config_env() != :test && role == "web" && not restore_mode &&
     System.get_env("GMAIL_OAUTH_FILE") do
  load_private_json = fn path ->
    case path && File.read(path) do
      {:ok, body} ->
        case Jason.decode(body) do
          {:ok, value} when is_map(value) -> value
          _ -> raise "Gmail configuration must be a JSON object"
        end

      _ ->
        raise "Gmail configuration file could not be read"
    end
  end

  oauth = load_private_json.(System.get_env("GMAIL_OAUTH_FILE"))["web"] || %{}
  keys = load_private_json.(System.get_env("GMAIL_KEYS_FILE"))
  redirect = System.get_env("GMAIL_REDIRECT_URI", "http://localhost:4000/auth/google/callback")
  uri = URI.parse(redirect)

  valid_origin =
    (uri.scheme == "https" && is_binary(uri.host) && uri.host != "") ||
      (config_env() == :dev && uri.scheme == "http" && uri.host == "localhost")

  unless valid_origin && uri.path == "/auth/google/callback" && is_nil(uri.query) &&
           is_nil(uri.fragment) && is_nil(uri.userinfo) &&
           redirect in (oauth["redirect_uris"] || []) do
    raise "Gmail redirect must match the registered callback and use HTTPS (localhost HTTP in development)"
  end

  for field <- ["client_id", "client_secret"] do
    unless is_binary(oauth[field]) && byte_size(oauth[field]) > 0,
      do: raise("Gmail OAuth client configuration is incomplete")
  end

  for field <- ["vault_key", "session_secret"] do
    unless is_binary(keys[field]) && byte_size(keys[field]) >= 64,
      do:
        raise(
          "Gmail keys must contain separate random vault_key and session_secret values of at least 64 bytes"
        )
  end

  unless keys["vault_key"] != keys["session_secret"] && is_binary(keys["allowed_email"]) &&
           String.contains?(keys["allowed_email"], "@"),
         do: raise("Gmail configuration requires separate keys and one allowed email address")

  config :email_sucks, :gmail,
    client_id: oauth["client_id"],
    client_secret: oauth["client_secret"],
    redirect_uri: redirect,
    allowed_email: String.downcase(String.trim(keys["allowed_email"])),
    vault_key: keys["vault_key"]

  config :email_sucks, EmailSucksWeb.Endpoint,
    secret_key_base: keys["session_secret"],
    debug_errors: false
end

if config_env() != :test and role == "web" and not restore_mode and
     System.get_env("GMAIL_OAUTH_FILE") do
  config :email_sucks, Oban,
    queues: [gmail_delivery: 1],
    plugins: [],
    lifeline: [rescue_after: {5, :minutes}]
end
