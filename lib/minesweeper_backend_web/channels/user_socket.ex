defmodule MinesweeperBackendWeb.UserSocket do
  @moduledoc """
  WebSocket entry point for the game.

  Clients open `/socket` without URL query params, join the single `"ws"`
  topic, then follow the FigJam protocol (`identify` → `welcome`, `join`,
  gameplay events, `ping`/`pong`).

  Per-user fanout inside a room uses `MinesweeperBackendWeb.RoomRegistry`,
  keyed by `{room_id, user_id}`.
  """

  use Phoenix.Socket

  channel("ws", MinesweeperBackendWeb.WsChannel)

  @impl true
  def connect(_params, socket), do: {:ok, socket}

  @impl true
  def id(%{assigns: %{user_id: user_id}}) when is_binary(user_id), do: "user_socket:#{user_id}"
  def id(_socket), do: nil
end
