defmodule MinesweeperBackendWeb.WsChannel do
  @moduledoc """
  Single WebSocket channel matching the FigJam protocol.

  Clients connect to `/socket`, join `"ws"`, then exchange messages in the
  form `["eventName", optionalJson]`:

    * `"identify"` → `"welcome"` (session handshake, 5s timeout)
    * `"ping"` → `"pong"` (heartbeat)
    * `"join"` → `"joined"` (room membership)
    * `"ready"` / `"cancelReady"` / `"startGame"` / `"boardClick"` / `"gameClear"`
  """

  use Phoenix.Channel

  alias MinesweeperBackend.{Accounts, Game, Rooms}
  alias MinesweeperBackendWeb.SocketAuth

  @impl true
  def join("ws", _params, socket) do
    timeout = Application.get_env(:minesweeper_backend, :socket_identify_timeout_ms, 5_000)
    ref = Process.send_after(self(), :identify_timeout, timeout)
    {:ok, assign(socket, :identify_timer, ref)}
  end

  @impl true
  def handle_in("identify", payload, socket) do
    cancel_identify_timer(socket)

    case session_id_from(payload) do
      {:ok, session_id} ->
        case SocketAuth.resolve(session_id) do
          {:ok, user_id} ->
            push(socket, "welcome", welcome_payload())

            {:reply, :ok,
             socket
             |> assign(:user_id, user_id)
             |> assign(:authenticated?, true)}

          {:error, :unauthorized} ->
            push(socket, "error", %{message: "인증이 필요합니다"})
            {:stop, :normal, socket}
        end

      :error ->
        push(socket, "error", %{message: "sessionId가 필요합니다"})
        {:reply, {:error, %{reason: "invalid_payload"}}, socket}
    end
  end

  def handle_in("ping", _payload, socket) do
    push(socket, "pong", %{})
    {:reply, :ok, socket}
  end

  def handle_in("join", %{"id" => room_id}, socket) when is_binary(room_id) do
    with {:ok, user_id} <- require_user_id(socket),
         {:ok, room} <- Rooms.fetch_room(room_id) do
      leave_current_room(socket)

      :ok = Rooms.add_member(room.id, user_id)
      :ok = Registry.register(MinesweeperBackendWeb.RoomRegistry, {room.id, user_id}, nil)

      socket = assign(socket, :room_id, room.id)
      users = list_room_users(room.id)
      broadcast_room(room.id, "joined", users)

      {:reply, :ok, socket}
    else
      {:error, :unauthorized} ->
        push(socket, "error", %{message: "identify가 필요합니다"})
        {:reply, {:error, %{reason: "unauthorized"}}, socket}

      {:error, :not_found} ->
        push(socket, "error", %{message: "방을 찾을 수 없습니다"})
        {:reply, {:error, %{reason: "not_found"}}, socket}
    end
  end

  def handle_in("join", _payload, socket) do
    push(socket, "error", %{message: "join.id가 필요합니다"})
    {:reply, {:error, %{reason: "invalid_payload"}}, socket}
  end

  def handle_in("ready", _payload, socket) do
    with {:ok, user_id} <- require_user_id(socket),
         {:ok, room_id} <- require_room_id(socket) do
      :ok = Rooms.mark_ready(room_id, user_id)
      payload = user_payload(user_id)
      broadcast_room(room_id, "ready", payload)
      {:reply, :ok, socket}
    else
      {:error, reason} -> reply_requirement_error(socket, reason)
    end
  end

  def handle_in("cancelReady", _payload, socket) do
    with {:ok, user_id} <- require_user_id(socket),
         {:ok, room_id} <- require_room_id(socket) do
      :ok = Rooms.cancel_ready(room_id, user_id)
      payload = user_payload(user_id)
      broadcast_room(room_id, "cancelReady", payload)
      {:reply, :ok, socket}
    else
      {:error, reason} -> reply_requirement_error(socket, reason)
    end
  end

  def handle_in("startGame", _payload, socket) do
    with {:ok, user_id} <- require_user_id(socket),
         {:ok, room_id} <- require_room_id(socket),
         {:ok, %{owner_id: ^user_id}} <- Rooms.fetch_room(room_id) do
      members = Rooms.list_members(room_id) |> Enum.sort()

      case Game.start_game(room_id, members) do
        {:ok, %{board: board, current_turn: first_turn}} ->
          broadcast_room(room_id, "gameStarted", %{})
          broadcast_room(room_id, "gameBoard", %{data: board})
          send_turn(room_id, first_turn)
          {:reply, :ok, socket}

        {:error, :not_enough_players} ->
          push(socket, "error", %{message: "플레이어가 2명 필요합니다"})
          {:noreply, socket}

        {:error, :already_playing} ->
          push(socket, "error", %{message: "이미 게임이 진행 중입니다"})
          {:noreply, socket}
      end
    else
      {:ok, _room} ->
        push(socket, "error", %{message: "방장만 게임을 시작할 수 있습니다"})
        {:noreply, socket}

      {:error, :not_found} ->
        push(socket, "error", %{message: "방을 찾을 수 없습니다"})
        {:noreply, socket}

      {:error, reason} ->
        reply_requirement_error(socket, reason)
    end
  end

  def handle_in("boardClick", %{"x" => x, "y" => y}, socket)
      when is_integer(x) and is_integer(y) do
    with {:ok, user_id} <- require_user_id(socket),
         {:ok, room_id} <- require_room_id(socket) do
      case Game.take_turn(room_id, user_id) do
        {:ok, :next_turn, next_user_id} ->
          payload = %{x: x, y: y, by: user_id}
          broadcast_room(room_id, "boardClick", payload, except: self())
          push(socket, "boardClick", payload)
          send_turn(room_id, next_user_id)
          {:reply, :ok, socket}

        {:error, :not_your_turn} ->
          push(socket, "error", %{message: "내 턴이 아닙니다"})
          {:noreply, socket}

        {:error, :no_game} ->
          push(socket, "error", %{message: "진행 중인 게임이 없습니다"})
          {:noreply, socket}

        {:error, :game_over} ->
          push(socket, "error", %{message: "게임이 종료되었습니다"})
          {:noreply, socket}
      end
    else
      {:error, reason} -> reply_requirement_error(socket, reason)
    end
  end

  def handle_in("boardClick", _payload, socket) do
    push(socket, "error", %{message: "boardClick x, y가 필요합니다"})
    {:reply, {:error, %{reason: "invalid_payload"}}, socket}
  end

  def handle_in("gameClear", _payload, socket) do
    with {:ok, user_id} <- require_user_id(socket),
         {:ok, room_id} <- require_room_id(socket) do
      case Game.report_clear(room_id, user_id) do
        {:ok, _} ->
          payload = %{winner: user_payload(user_id)}
          broadcast_room(room_id, "gameClear", payload)
          push(socket, "gameClear", payload)
          {:reply, :ok, socket}

        {:error, :no_active_game} ->
          push(socket, "error", %{message: "클리어할 게임이 없습니다"})
          {:noreply, socket}

        {:error, :not_a_player} ->
          push(socket, "error", %{message: "플레이어만 클리어를 보고할 수 있습니다"})
          {:noreply, socket}
      end
    else
      {:error, reason} -> reply_requirement_error(socket, reason)
    end
  end

  def handle_in(_event, _payload, socket), do: {:noreply, socket}

  @impl true
  def handle_info(:identify_timeout, socket) do
    if socket.assigns[:user_id] do
      {:noreply, socket}
    else
      push(socket, "error", %{message: "identify 시간이 초과되었습니다"})
      {:stop, :normal, socket}
    end
  end

  def handle_info({:room_push, event, payload}, socket) do
    push(socket, event, payload)
    {:noreply, socket}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    leave_current_room(socket)
    :ok
  end

  defp session_id_from(%{"sessionId" => session_id}) when is_binary(session_id), do: {:ok, session_id}
  defp session_id_from(%{"session_id" => session_id}) when is_binary(session_id), do: {:ok, session_id}
  defp session_id_from(_), do: :error

  defp require_user_id(%{assigns: %{user_id: user_id}}) when is_binary(user_id), do: {:ok, user_id}
  defp require_user_id(_), do: {:error, :unauthorized}

  defp require_room_id(%{assigns: %{room_id: room_id}}) when is_binary(room_id), do: {:ok, room_id}
  defp require_room_id(_), do: {:error, :not_in_room}

  defp reply_requirement_error(socket, :unauthorized) do
    push(socket, "error", %{message: "identify가 필요합니다"})
    {:reply, {:error, %{reason: "unauthorized"}}, socket}
  end

  defp reply_requirement_error(socket, :not_in_room) do
    push(socket, "error", %{message: "방에 입장해야 합니다"})
    {:reply, {:error, %{reason: "not_in_room"}}, socket}
  end

  defp welcome_payload do
    app = :minesweeper_backend

    %{
      pingInterval: Application.get_env(app, :socket_ping_interval_ms, 10_000)
    }
  end

  defp cancel_identify_timer(%{assigns: %{identify_timer: ref}} = socket) when is_reference(ref) do
    Process.cancel_timer(ref)
    assign(socket, :identify_timer, nil)
  end

  defp cancel_identify_timer(socket), do: socket

  defp leave_current_room(socket) do
    user_id = socket.assigns[:user_id]
    room_id = socket.assigns[:room_id]

    if user_id && room_id do
      :ok = Rooms.remove_member(room_id, user_id)
      :ok = Rooms.cancel_ready(room_id, user_id)
      Registry.unregister(MinesweeperBackendWeb.RoomRegistry, {room_id, user_id})
    end

    :ok
  end

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

  defp broadcast_room(room_id, event, payload, opts \\ []) do
    except = Keyword.get(opts, :except)

    Enum.each(Rooms.list_members(room_id), fn user_id ->
      case Registry.lookup(MinesweeperBackendWeb.RoomRegistry, {room_id, user_id}) do
        [{pid, _}] ->
          if is_nil(except) or pid != except do
            send(pid, {:room_push, event, payload})
          end

        _ ->
          :ok
      end
    end)
  end

  defp send_turn(room_id, turn_user_id) do
    broadcast_room(room_id, "turn", %{userId: turn_user_id})
  end
end
