defmodule MinesweeperBackendWeb.RoomChannel do
  @moduledoc """
  Per-room Phoenix.Channel.

  Topic format is `"room:<room_id>"`. Membership is maintained by
  the caller (the WebSocket layer calls `Rooms.add_member/2` on
  successful join) and the channel pushes the resulting roster back
  to the client.

  Events emitted by the client:

    * `"ready"`        – mark the joining user as ready.
    * `"cancelReady"`  – clear the joining user's ready flag.
    * `"startGame"`    – owner-only; starts a new round.
    * `"boardClick"`   – the acting player's click; advances the turn.
    * `"gameClear"`    – the acting player reports that they have
                         cleared the board. Server marks the game
                         as `:cleared` and broadcasts the winner.

  Events pushed to the client:

    * `"joined"`         – `%{users: [APIUser]}` (broadcast on join).
    * `"ready"`          – `%APIUser{}` (broadcast on ready).
    * `"cancelReady"`    – `%APIUser{}` (broadcast on cancel).
    * `"gameStarted"`    – `%{}` (broadcast, no payload yet).
    * `"gameBoard"`      – `%{data: <Base85 board>}` (broadcast).
    * `"boardClick"`     – `%{x, y, by}` (broadcast).
    * `"turn"`           – `%{}` (sent to the player whose turn it is).
    * `"gameClear"`      – `%{winner: APIUser}` (broadcast).
    * `"error"`          – `%APIError{message: ...}`.

  After `gameClear`, the same room can host a new round: clients
  send `cancelReady` to drop their ready flag, `ready` to re-arm,
  and the owner sends `startGame` to begin a new game. The server
  keeps the ready state per-client and resets game state when
  `startGame` is accepted.
  """

  use Phoenix.Channel

  alias MinesweeperBackend.{Accounts, Game, Rooms}

  @impl true
  def join("room:" <> room_id, _params, socket) do
    case socket.assigns[:user_id] do
      nil ->
        {:error, %{reason: "identify first"}}

      user_id ->
        join_room(room_id, user_id, socket)
    end
  end

  defp join_room(room_id, user_id, socket) do
    with {:ok, room} <- Rooms.fetch_room(room_id) do
      :ok = Rooms.add_member(room.id, user_id)
      Registry.register(MinesweeperBackendWeb.RoomRegistry, {room.id, user_id}, nil)
      send(self(), {:after_join, room.id})

      {:ok, assign(socket, :room_id, room.id)}
    else
      {:error, :not_found} -> {:error, %{code: :not_found, reason: "room not found"}}
    end
  end

  @impl true
  def handle_info({:after_join, room_id}, socket) do
    users = list_room_users(room_id)
    broadcast(socket, "joined", %{users: users})
    {:noreply, socket}
  end

  def handle_info({:user_push, event, payload}, socket) do
    push(socket, event, payload)
    {:noreply, socket}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_in("ready", _payload, socket) do
    user_id = socket.assigns.user_id
    room_id = socket.assigns.room_id

    :ok = Rooms.mark_ready(room_id, user_id)
    broadcast_from!(socket, "ready", user_payload(user_id))
    {:reply, :ok, socket}
  end

  def handle_in("cancelReady", _payload, socket) do
    user_id = socket.assigns.user_id
    room_id = socket.assigns.room_id

    :ok = Rooms.cancel_ready(room_id, user_id)
    broadcast_from!(socket, "cancelReady", user_payload(user_id))
    {:reply, :ok, socket}
  end

  def handle_in("startGame", _payload, socket) do
    room_id = socket.assigns.room_id
    user_id = socket.assigns.user_id

    case Rooms.fetch_room(room_id) do
      {:ok, %{owner_id: ^user_id}} ->
        members = Rooms.list_members(room_id) |> Enum.sort()

        case Game.start_game(room_id, members) do
          {:ok, %{board: board, current_turn: first_turn}} ->
            broadcast(socket, "gameStarted", %{})
            broadcast(socket, "gameBoard", %{data: board})

            if first_turn == user_id do
              push(socket, "turn", %{})
            else
              send_to_user(socket, first_turn, "turn", %{})
            end

            {:reply, :ok, socket}

          {:error, :not_enough_players} ->
            push(socket, "error", %{message: "need 2 players to start"})
            {:noreply, socket}

          {:error, :already_playing} ->
            push(socket, "error", %{message: "a game is already in progress"})
            {:noreply, socket}
        end

      {:ok, _room} ->
        push(socket, "error", %{message: "only the owner can start the game"})
        {:noreply, socket}

      {:error, :not_found} ->
        push(socket, "error", %{message: "room not found"})
        {:noreply, socket}
    end
  end

  def handle_in("boardClick", %{"x" => x, "y" => y}, socket)
      when is_integer(x) and is_integer(y) do
    room_id = socket.assigns.room_id
    user_id = socket.assigns.user_id

    case Game.take_turn(room_id, user_id) do
      {:ok, :next_turn, next_user_id} ->
        broadcast_from!(socket, "boardClick", %{x: x, y: y, by: user_id})

        if next_user_id == user_id do
          push(socket, "turn", %{})
        else
          send_to_user(socket, next_user_id, "turn", %{})
        end

        {:reply, :ok, socket}

      {:error, :not_your_turn} ->
        push(socket, "error", %{message: "not your turn"})
        {:noreply, socket}

      {:error, :no_game} ->
        push(socket, "error", %{message: "no game in progress"})
        {:noreply, socket}

      {:error, :game_over} ->
        push(socket, "error", %{message: "the game is over"})
        {:noreply, socket}
    end
  end

  def handle_in("boardClick", _payload, socket) do
    push(socket, "error", %{message: "invalid boardClick payload"})
    {:noreply, socket}
  end

  def handle_in("gameClear", _payload, socket) do
    room_id = socket.assigns.room_id
    user_id = socket.assigns.user_id

    case Game.report_clear(room_id, user_id) do
      {:ok, _} ->
        winner_payload = user_payload(user_id)
        broadcast(socket, "gameClear", %{winner: winner_payload})
        {:reply, :ok, socket}

      {:error, :no_active_game} ->
        push(socket, "error", %{message: "no active game to clear"})
        {:noreply, socket}

      {:error, :not_a_player} ->
        push(socket, "error", %{message: "only players can report a clear"})
        {:noreply, socket}
    end
  end

  def handle_in(_event, _payload, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    user_id = Map.get(socket.assigns, :user_id)
    room_id = Map.get(socket.assigns, :room_id)

    if user_id && room_id do
      :ok = Rooms.remove_member(room_id, user_id)
      :ok = Rooms.cancel_ready(room_id, user_id)
      Registry.unregister(MinesweeperBackendWeb.RoomRegistry, {room_id, user_id})
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # private helpers
  # ---------------------------------------------------------------------------

  defp list_room_users(room_id) do
    Rooms.list_members(room_id)
    |> Enum.map(&user_payload/1)
  end

  defp user_payload(user_id) do
    case Accounts.fetch_user_by_session(user_id) do
      {:ok, user} -> %{id: user.id, name: user.name}
      _ -> %{id: user_id, name: nil}
    end
  end

  defp send_to_user(socket, user_id, event, payload) do
    key = {socket.assigns.room_id, user_id}

    case Registry.lookup(MinesweeperBackendWeb.RoomRegistry, key) do
      [{pid, _}] -> send(pid, {:user_push, event, payload})
      _ -> :ok
    end

    :ok
  end
end
