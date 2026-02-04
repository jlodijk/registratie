import Config
alias Dotenvy

Dotenvy.source!(Path.expand(".env"))

if System.get_env("PHX_SERVER") do
  config :registratie, RegistratieWeb.Endpoint, server: true
end

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :registratie, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :registratie, RegistratieWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base
end

config :registratie,
  couchdb_username: Dotenvy.env!("COUCHDB_USERNAME", :string!),
  couchdb_password: Dotenvy.env!("COUCHDB_PASSWORD", :string!),
  couchdb_url: Dotenvy.env!("COUCHDB_URL", :string!),
  couchdb_secondary_url: System.get_env("COUCHDB_SECONDARY_URL"),
  couchdb_secondary_username: System.get_env("COUCHDB_SECONDARY_USERNAME"),
  couchdb_secondary_password: System.get_env("COUCHDB_SECONDARY_PASSWORD")

database_url =
  System.get_env("DATABASE_URL") ||
    if config_env() == :dev do
      "ecto://reg_user:Reg123!!@127.0.0.1:5432/registratie"
    else
      raise """
      environment variable DATABASE_URL is missing.
      Example: ecto://USER:PASS@localhost:5432/registratie
      """
    end

pool_size = String.to_integer(System.get_env("POOL_SIZE") || "10")

config :registratie, Registratie.Repo,
  url: database_url,
  pool_size: pool_size,
  ssl: false
