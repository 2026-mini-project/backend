defmodule MinesweeperBackendWeb.UserSocket do
  @moduledoc """
  WebSocket entry point for the game.

  Handshake / heartbeat flow:

    1. `connect/3` runs as soon as the upgrade succeeds. We start a
       server-side timer that gives the client
       `socket_identify_timeout_ms` (default 5_000 ms) to send an
       `identify` event carrying their `session_id`. If that timer
       fires before we have a user, we close the socket.

    2. When the client emits `identify` (either right after `connect`
       or as a follow-up within the timeout), we resolve the
       `session_id` against the existing `session:<sid>` cache via
       `MinesweeperBackendWeb.SocketAuth`. If the session is unknown
       we close the socket with `:unauthorized`; otherwise we
       acknowledge with a `welcome` event that contains the
       server-controlled `pingInterval` (ms) the client should use.

    3. After a successful `identify` we start a heartbeat: the client
       must send `ping` at most every `pingInterval` ms, and the
       server replies with `pong`. We also start a `pong-deadline`
       timer of `pingInterval + pongTimeout` ms. Each `ping` resets
       that timer. If the deadline fires before the next `ping` we
       close the socket.

  `pingInterval` and `pongTimeout` are read from application config
  on every successful `identify`, so the server can tune them
  without redeploying the client.
  """

  use Phoenix.Socket

  alias MinesweeperBackendWeb.SocketAuth

  channel("room:*", MinesweeperBackendWeb.RoomChannel)

  @impl true
  def connect(_params, connect_info, socket) do
    config = socket_config()
    identify_after = connect_info[:identify_after]

    socket =
      socket
      |> Phoenix.Socket.assign(:state, :awaiting_identify)
      |> Phoenix.Socket.assign(:identify_timer, nil)
      |> Phoenix.Socket.assign(:pong_deadline, nil)

    case identify_after do
      %{"session_id" => sid} ->
        handle_identify(sid, socket, config)

      _ ->
        {:ok, schedule_identify_timeout(socket, config)}
    end
  end

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"

  @impl true
  def handle_info(:identify_timeout, socket) do
    push_error_and_close(socket, "identify timeout")
  end

  def handle_info(:pong_timeout, socket) do
    push(socket, "error", %{message: "pong timeout"})
    {:stop, :pong_timeout, socket}
  end

  # ---------------------------------------------------------------------------
  # identify handling
  # ---------------------------------------------------------------------------

  def handle_in("identify", %{"session_id" => session_id}, socket) do
    handle_identify(session_id, socket, socket_config())
  end

  def handle_in("identify", _payload, socket) do
    push_error_and_close(socket, "missing session_id")
  end

  def handle_in(_event, _payload, socket) when socket.assigns.state == :awaiting_identify do
    push_error_and_close(socket, "identify required")
  end

  def handle_in("join", %{"id" => room_id}, socket) when is_binary(room_id) do
    topic = "room:" <> room_id
    ref = Phoenix.Socket.Message.new_ref()
    msg = %Phoenix.Socket.Message{topic: topic, event: "phx_join", payload: %{}, ref: ref}

    send(self(), msg)
    {:ok, socket}
  end

  def handle_in("join", _payload, socket) do
    push(socket, "error", %{message: "missing room id"})
    {:ok, socket}
  end

  # ---------------------------------------------------------------------------
  # ping/pong (only valid after identify)
  # ---------------------------------------------------------------------------

  def handle_in("ping", payload, socket) do
    config = socket_config()
    socket = reset_pong_deadline(socket, config)

    reply =
      case payload do
        %{} = p -> p
        _ -> %{}
      end

    {:reply, {:ok, %{reply: "pong", echo: reply}}, socket}
  end

  def handle_in(_event, _payload, socket) do
    {:ok, socket}
  end

  # ---------------------------------------------------------------------------
  # private helpers
  # ---------------------------------------------------------------------------

  defp handle_identify(session_id, socket, config) do
    cancel_identify_timer(socket)

    case SocketAuth.resolve(session_id) do
      {:ok, user_id} ->
        socket =
          socket
          |> Phoenix.Socket.assign(:user_id, user_id)
          |> Phoenix.Socket.assign(:state, :authenticated)
          |> push_welcome(config)
          |> reset_pong_deadline(config)

        {:ok, socket}

      {:error, :unauthorized} ->
        push_error_and_close(socket, "unauthorized")
    end
  end

  defp push_welcome(socket, config) do
    payload = %{
      pingInterval: config.ping_interval_ms,
      pongTimeout: config.pong_timeout_ms
    }

    push(socket, "welcome", payload)
    socket
  end

  defp schedule_identify_timeout(socket, config) do
    timer = Process.send_after(self(), :identify_timeout, config.identify_timeout_ms)
    Phoenix.Socket.assign(socket, :identify_timer, timer)
  end

  defp cancel_identify_timer(socket) do
    case socket.assigns[:identify_timer] do
      nil -> :ok
      ref -> Process.cancel_timer(ref)
    end

    Phoenix.Socket.assign(socket, :identify_timer, nil)
  end

  defp reset_pong_deadline(socket, config) do
    cancel_pong_deadline(socket)

    deadline = config.ping_interval_ms + config.pong_timeout_ms
    ref = Process.send_after(self(), :pong_timeout, deadline)
    Phoenix.Socket.assign(socket, :pong_deadline, ref)
  end

  defp cancel_pong_deadline(socket) do
    case socket.assigns[:pong_deadline] do
      nil -> :ok
      ref -> Process.cancel_timer(ref)
    end

    Phoenix.Socket.assign(socket, :pong_deadline, nil)
  end

  defp push_error_and_close(socket, message) do
    push(socket, "error", %{message: message})
    {:error, %{code: :unauthorized, reason: message}}
  end

  defp socket_config do
    app = :minesweeper_backend

    %{
      identify_timeout_ms: Application.get_env(app, :socket_identify_timeout_ms, 5_000),
      ping_interval_ms: Application.get_env(app, :socket_ping_interval_ms, 10_000),
      pong_timeout_ms: Application.get_env(app, :socket_pong_timeout_ms, 3_000)
    }
  end
end
