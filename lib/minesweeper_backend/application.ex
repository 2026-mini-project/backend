defmodule MinesweeperBackend.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MinesweeperBackendWeb.Telemetry,
      MinesweeperBackend.MemoryStore,
      {DNSCluster, query: Application.get_env(:minesweeper_backend, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MinesweeperBackend.PubSub},
      {Registry, keys: :duplicate, name: MinesweeperBackendWeb.RoomRegistry},
      MinesweeperBackend.RoomJanitor,
      MinesweeperBackendWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: MinesweeperBackend.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    MinesweeperBackendWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
