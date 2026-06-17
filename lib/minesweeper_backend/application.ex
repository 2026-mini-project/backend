defmodule MinesweeperBackend.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        MinesweeperBackendWeb.Telemetry,
        storage_child(),
        {DNSCluster,
         query: Application.get_env(:minesweeper_backend, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: MinesweeperBackend.PubSub},
        {Registry, keys: :duplicate, name: MinesweeperBackendWeb.RoomRegistry},
        redix_child(),
        MinesweeperBackendWeb.Endpoint
      ]
      |> Enum.reject(&is_nil/1)

    opts = [strategy: :one_for_one, name: MinesweeperBackend.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    MinesweeperBackendWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp storage_child do
    if memory_storage?(), do: MinesweeperBackend.MemoryStore, else: MinesweeperBackend.Repo
  end

  defp redix_child do
    if memory_storage?(), do: nil, else: MinesweeperBackend.Redix
  end

  defp memory_storage? do
    Application.get_env(:minesweeper_backend, :storage_driver) == "memory"
  end
end
