defmodule MinesweeperBackendWeb.UserSocket do
  @moduledoc """
  WebSocket entry point for the game.

  The transport is a vanilla Phoenix Channels v2 client. All
  application-level events live in `MinesweeperBackendWeb.RoomChannel`
  (topic `"room:<room_id>"`), the only thing the socket itself does is
  authenticate the connecting user during the HTTP upgrade.

  ## Authentication

  The client must call `socket.connect({session_id: "..."})` (or
  equivalent) when opening the WebSocket. `session_id` is the UUID
  the client received from `POST /session`. We resolve it against the
  `session:<sid>` cache via `MinesweeperBackendWeb.SocketAuth` and
  reject the upgrade if the session is unknown.

  ## Welcome / heartbeat

  The first `room:<id>` channel that the client joins receives a
  `welcome` payload in its join reply. The payload includes
  `pingInterval` and `pongTimeout` in milliseconds, read from app
  config so the server can tune them without a client redeploy.

  Heartbeats use the built-in `"phoenix"` topic `"heartbeat"` event
  which the transport replies to automatically. Clients should ping
  the server at most every `pingInterval` ms and tolerate up to
  `pingInterval + pongTimeout` ms of silence before reconnecting.

  ## Channel routing

  `MinesweeperBackendWeb.RoomChannel` is registered for `room:*`
  topics. Per-user fanout inside a room (e.g. sending `turn` to a
  specific client) is done via `MinesweeperBackendWeb.RoomRegistry`,
  keyed by `{room_id, user_id}` → channel pid.
  """

  use Phoenix.Socket

  alias MinesweeperBackendWeb.SocketAuth

  channel("room:*", MinesweeperBackendWeb.RoomChannel)

  @impl true
  def connect(%{"session_id" => session_id}, socket) when is_binary(session_id) do
    case SocketAuth.resolve(session_id) do
      {:ok, user_id} ->
        {:ok, Phoenix.Socket.assign(socket, :user_id, user_id)}

      {:error, :unauthorized} ->
        :error
    end
  end

  def connect(_params, _socket), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
