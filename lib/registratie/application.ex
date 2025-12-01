defmodule Registratie.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RegistratieWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:registratie, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Registratie.PubSub},
      Registratie.Repo,
      # Start the Finch HTTP client for sending emails
      {Finch, name: Registratie.Finch},
      # Start a worker by calling: Registratie.Worker.start_link(arg)
      # {Registratie.Worker, arg},
      # Start to serve requests, typically the last entry
      RegistratieWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Registratie.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RegistratieWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
