
defmodule Reoxt.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ReoxtWeb.Telemetry,
      Reoxt.Repo,
      {DNSCluster, query: Application.get_env(:reoxt, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Reoxt.PubSub},
      {Finch, name: Reoxt.Finch},
      Reoxt.BitcoinRPC,
      ReoxtWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Reoxt.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ReoxtWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
