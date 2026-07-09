defmodule MinesweeperBackendWeb.WsHandler do
  @moduledoc """
  Raw WebSocket handler for the FigJam game protocol.

  Clients connect to `/socket` and exchange JSON text frames shaped as
  `["eventName", optionalPayload]` — the same shape you send and receive
  with the HTML5 `WebSocket` API (`event.data` / `ws.send(...)`).
  """

  @behaviour WebSock

  alias MinesweeperBackend.{Accounts, Game, Rooms}
  alias MinesweeperBackendWeb.SocketAuth

  @impl WebSock
  def init(_state) do
    timeout = Application.get_env(:minesweeper_backend, :socket_identify_timeout_ms, 5_000)
    ref = Process.send_after(self(), :identify_timeout, timeout)
    {:ok, %{user_id: nil, room_id: nil, identify_timer: ref}}
  end

  @impl WebSock
  def handle_in({raw, opcode: :text}, state) when is_binary(raw), do: dispatch_message(raw, state)

  def handle_in(_frame, state), do: {:ok, state}

  @impl WebSock
  def handle_info(:identify_timeout, %{user_id: user_id} = state) when not is_nil(user_id) do
    {:ok, state}
  end

  def handle_info(:identify_timeout, state) do
    Process.send_after(self(), :ws_close, 50)
    push(state, "error", %{message: "identify 시간이 초과되었습니다"})
  end

  def handle_info(:ws_close, state), do: {:stop, :normal, state}

  def handle_info({:room_push, event, payload}, state) do
    push(state, event, payload)
  end

  def handle_info(_msg, state), do: {:ok, state}

  @impl WebSock
  def terminate(_reason, state) do
    leave_current_room(state)
    cancel_identify_timer(state)
    :ok
  end

  defp dispatch_message(raw, state) do
    case decode_message(raw) do
      {:ok, "identify", payload} -> handle_identify(payload, state)
      {:ok, "ping", payload} -> handle_ping(payload, state)
      {:ok, "join", payload} -> handle_join(payload, state)
      {:ok, "ready", payload} -> handle_ready(payload, state)
      {:ok, "cancelReady", payload} -> handle_cancel_ready(payload, state)
      {:ok, "startGame", payload} -> handle_start_game(payload, state)
      {:ok, "boardClick", payload} -> handle_board_click(payload, state)
      {:ok, "gameClear", payload} -> handle_game_clear(payload, state)
      {:ok, _event, _payload} -> {:ok, state}
      :error -> {:ok, state}
    end
  end

  defp handle_identify(payload, state) do
    state = cancel_identify_timer(state)

    case session_id_from(payload) do
      {:ok, session_id} ->
        case SocketAuth.resolve(session_id) do
          {:ok, user_id} ->
            state
            |> Map.put(:user_id, user_id)
            |> then(&push(&1, "welcome", welcome_payload()))

          {:error, :unauthorized} ->
            Process.send_after(self(), :ws_close, 50)
            push(state, "error", %{message: "인증이 필요합니다"})
        end

      :error ->
        push(state, "error", %{message: "sessionId가 필요합니다"})
    end
  end

  defp handle_ping(_payload, state), do: push(state, "pong", %{})

  defp handle_join(%{"id" => room_id}, state) when is_binary(room_id) do
    with {:ok, user_id} <- require_user_id(state),
         {:ok, room} <- Rooms.fetch_room(room_id) do
      state = leave_current_room(state)

      :ok = Rooms.add_member(room.id, user_id)
      Registry.register(MinesweeperBackendWeb.RoomRegistry, {room.id, user_id}, nil)

      state = Map.put(state, :room_id, room.id)
      broadcast_room(room.id, "joined", list_room_users(room.id))
      {:ok, state}
    else
      {:error, :unauthorized} ->
        push(state, "error", %{message: "identify가 필요합니다"})

      {:error, :not_found} ->
        push(state, "error", %{message: "방을 찾을 수 없습니다"})
    end
  end

  defp handle_join(_payload, state) do
    push(state, "error", %{message: "join.id가 필요합니다"})
  end

  defp handle_ready(_payload, state) do
    with {:ok, user_id} <- require_user_id(state),
         {:ok, room_id} <- require_room_id(state) do
      :ok = Rooms.mark_ready(room_id, user_id)
      broadcast_room(room_id, "ready", user_payload(user_id))
      {:ok, state}
    else
      {:error, reason} -> reply_requirement_error(state, reason)
    end
  end

  defp handle_cancel_ready(_payload, state) do
    with {:ok, user_id} <- require_user_id(state),
         {:ok, room_id} <- require_room_id(state) do
      :ok = Rooms.cancel_ready(room_id, user_id)
      broadcast_room(room_id, "cancelReady", user_payload(user_id))
      {:ok, state}
    else
      {:error, reason} -> reply_requirement_error(state, reason)
    end
  end

  defp handle_start_game(_payload, state) do
    with {:ok, user_id} <- require_user_id(state),
         {:ok, room_id} <- require_room_id(state),
         {:ok, %{owner_id: ^user_id}} <- Rooms.fetch_room(room_id) do
      members = Rooms.list_members(room_id) |> Enum.sort()

      case Game.start_game(room_id, members) do
        {:ok, %{board: board, current_turn: first_turn}} ->
          broadcast_room(room_id, "gameStarted", %{})
          broadcast_room(room_id, "gameBoard", %{data: board})
          send_turn(room_id, first_turn)
          {:ok, state}

        {:error, :not_enough_players} ->
          push(state, "error", %{message: "플레이어가 2명 필요합니다"})

        {:error, :already_playing} ->
          push(state, "error", %{message: "이미 게임이 진행 중입니다"})
      end
    else
      {:ok, _room} ->
        push(state, "error", %{message: "방장만 게임을 시작할 수 있습니다"})

      {:error, :not_found} ->
        push(state, "error", %{message: "방을 찾을 수 없습니다"})

      {:error, reason} ->
        reply_requirement_error(state, reason)
    end
  end

  defp handle_board_click(%{"x" => x, "y" => y}, state)
       when is_integer(x) and is_integer(y) do
    with {:ok, user_id} <- require_user_id(state),
         {:ok, room_id} <- require_room_id(state) do
      case Game.take_turn(room_id, user_id) do
        {:ok, :next_turn, next_user_id} ->
          payload = %{x: x, y: y, by: user_id}
          broadcast_room(room_id, "boardClick", payload, except: self())
          send_turn(room_id, next_user_id)

          push(state, "boardClick", payload)

        {:error, :not_your_turn} ->
          push(state, "error", %{message: "내 턴이 아닙니다"})

        {:error, :no_game} ->
          push(state, "error", %{message: "진행 중인 게임이 없습니다"})

        {:error, :game_over} ->
          push(state, "error", %{message: "게임이 종료되었습니다"})
      end
    else
      {:error, reason} -> reply_requirement_error(state, reason)
    end
  end

  defp handle_board_click(_payload, state) do
    push(state, "error", %{message: "boardClick x, y가 필요합니다"})
  end

  defp handle_game_clear(_payload, state) do
    with {:ok, user_id} <- require_user_id(state),
         {:ok, room_id} <- require_room_id(state) do
      case Game.report_clear(room_id, user_id) do
        {:ok, _} ->
          payload = %{winner: user_payload(user_id)}
          broadcast_room(room_id, "gameClear", payload)

          state
          |> then(&push(&1, "gameClear", payload))

        {:error, :no_active_game} ->
          push(state, "error", %{message: "클리어할 게임이 없습니다"})

        {:error, :not_a_player} ->
          push(state, "error", %{message: "플레이어만 클리어를 보고할 수 있습니다"})
      end
    else
      {:error, reason} -> reply_requirement_error(state, reason)
    end
  end

  defp decode_message(raw) when is_binary(raw) do
    case Jason.decode(raw) do
      {:ok, [event]} when is_binary(event) ->
        {:ok, event, %{}}

      {:ok, [event, payload]} when is_binary(event) and is_map(payload) ->
        {:ok, event, payload}

      _ ->
        :error
    end
  end

  defp decode_message(_), do: :error

  defp encode_message(event, payload) when map_size(payload) == 0, do: Jason.encode!([event])
  defp encode_message(event, payload), do: Jason.encode!([event, payload])

  defp push(state, event, payload \\ %{}) do
    {:push, [{:text, encode_message(event, payload)}], state}
  end

  defp session_id_from(%{"sessionId" => session_id}) when is_binary(session_id), do: {:ok, session_id}
  defp session_id_from(%{"session_id" => session_id}) when is_binary(session_id), do: {:ok, session_id}
  defp session_id_from(_), do: :error

  defp require_user_id(%{user_id: user_id}) when is_binary(user_id), do: {:ok, user_id}
  defp require_user_id(_), do: {:error, :unauthorized}

  defp require_room_id(%{room_id: room_id}) when is_binary(room_id), do: {:ok, room_id}
  defp require_room_id(_), do: {:error, :not_in_room}

  defp reply_requirement_error(state, :unauthorized) do
    push(state, "error", %{message: "identify가 필요합니다"})
  end

  defp reply_requirement_error(state, :not_in_room) do
    push(state, "error", %{message: "방에 입장해야 합니다"})
  end

  defp welcome_payload do
    app = :minesweeper_backend

    %{
      pingInterval: Application.get_env(app, :socket_ping_interval_ms, 10_000)
    }
  end

  defp cancel_identify_timer(%{identify_timer: ref} = state) when is_reference(ref) do
    Process.cancel_timer(ref)
    Map.put(state, :identify_timer, nil)
  end

  defp cancel_identify_timer(state), do: state

  defp leave_current_room(state) do
    user_id = state[:user_id]
    room_id = state[:room_id]

    if user_id && room_id do
      :ok = Rooms.remove_member(room_id, user_id)
      :ok = Rooms.cancel_ready(room_id, user_id)
      Registry.unregister(MinesweeperBackendWeb.RoomRegistry, {room_id, user_id})
    end

    Map.put(state, :room_id, nil)
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
