defmodule Reoxt.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ReoxtWeb.Telemetry,
      Reoxt.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:reoxt, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:reoxt, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Reoxt.PubSub},
      # Start Bitcoin RPC client and transaction fetcher
      Reoxt.BitcoinRpcClient,
      Reoxt.TransactionFetcher,
      # Start a worker by calling: Reoxt.Worker.start_link(arg)
      # {Reoxt.Worker, arg},
      # Start to serve requests, typically the last entry
      ReoxtWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Reoxt.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ReoxtWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end