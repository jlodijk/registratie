# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :registratie,
  generators: [timestamp_type: :utc_datetime],
  ecto_repos: [Registratie.Repo],
  ash_domains: [Registratie.Accounts]

# Configures the endpoint
config :registratie, RegistratieWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: RegistratieWeb.ErrorHTML, json: RegistratieWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Registratie.PubSub,
  live_view: [signing_salt: "1y5CaPVn"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :registratie, Registratie.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  registratie: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  registratie: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# couchdb roles
config :registratie, :couchdb,
  base_url: "http://elixir:Elixir123@localhost:5984",
  roles_db: "roles"

config :registratie, :attendance_db, "aanwezig"
config :registratie, :laptops_db, "laptops"
config :registratie, :oase_rules_db, "oase_regels"
config :registratie, :network_db, "netwerk"
config :registratie, :missions_db, "missies"
config :registratie, :help_requests_db, "hulpvragen"

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

# Configures Elixir's Logger
config :logger,
  backends: [
    :console,
    Registratie.Logger.ErrorFileBackend,
    Registratie.Logger.LoginFileBackend
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :logger, Registratie.Logger.ErrorFileBackend,
  path: "log/errors/error.log",
  level: :error,
  metadata: [:request_id],
  format: "$date $time [$level] $message $metadata\n"

config :logger, Registratie.Logger.LoginFileBackend,
  path: "log/login.log",
  level: :info,
  metadata: [:request_id],
  format: "$date $time [$level] $message $metadata\n"

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
