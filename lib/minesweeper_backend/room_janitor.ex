defmodule MinesweeperBackend.RoomJanitor do
  @moduledoc false

  use GenServer

  alias MinesweeperBackend.Rooms

  @tick_interval_ms 300_000

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    schedule_tick()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:tick, state) do
    :ok = Rooms.cleanup_stale_empty_rooms()
    schedule_tick()
    {:noreply, state}
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_interval_ms)
  end
end
