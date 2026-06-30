defmodule MinesweeperBackendWeb.UserSocket do
  @moduledoc """
  WebSocket entry point for the game.

  Clients open `/socket` without URL query params. Authentication happens
  on the `"auth"` topic via the `"identify"` event (see
  `MinesweeperBackendWeb.AuthChannel`). After a successful identify the
  socket carries `:user_id`, which room channels require before join.

  ## Channel routing

  * `"auth"` – session handshake (`identify` → `welcome`).
  * `"room:<room_id>"` – gameplay (`MinesweeperBackendWeb.RoomChannel`).

  Per-user fanout inside a room (e.g. sending `turn` to a specific client)
  uses `MinesweeperBackendWeb.RoomRegistry`, keyed by `{room_id, user_id}`.
  """

  use Phoenix.Socket

  channel("auth", MinesweeperBackendWeb.AuthChannel)
  channel("room:*", MinesweeperBackendWeb.RoomChannel)

  @impl true
  def connect(_params, socket), do: {:ok, socket}

  @impl true
  def id(%{assigns: %{user_id: user_id}}) when is_binary(user_id), do: "user_socket:#{user_id}"
  def id(_socket), do: nil
end
