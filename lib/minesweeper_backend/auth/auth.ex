defmodule MinesweeperBackend.Auth do
  @moduledoc """
  Placeholder for the historical `MinesweeperBackend.Auth` module.

  Originally the codebase referenced a `use MyApp.Web, :channel`
  helper that does not exist in this project. The real authentication
  happens in `MinesweeperBackendWeb.SocketAuth` (WebSocket
  handshake) and `MinesweeperBackendWeb.Plugs.Authenticate` (HTTP).
  This module is kept only so the previous module name keeps
  compiling; it is not registered as a channel and should be removed
  once the codebase stops referencing it.
  """

  use Phoenix.Channel

  def join(_topic, _payload, socket), do: {:ok, socket}

  def handle_in(_event, _payload, socket), do: {:noreply, socket}
end
