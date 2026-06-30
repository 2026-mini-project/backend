defmodule MinesweeperBackendWeb.AuthChannel do
  @moduledoc """
  Session handshake channel.

  Clients connect to `/socket` without query params, join `"auth"`, then
  push `"identify"` with `%{"session_id" => session_id}`. On success the
  server assigns `:user_id` on the socket and pushes `"welcome"`.
  """

  use Phoenix.Channel

  alias MinesweeperBackendWeb.SocketAuth

  @impl true
  def join("auth", _params, socket) do
    timeout = Application.get_env(:minesweeper_backend, :socket_identify_timeout_ms, 5_000)
    ref = Process.send_after(self(), :identify_timeout, timeout)
    {:ok, assign(socket, :identify_timer, ref)}
  end

  @impl true
  def handle_in("identify", %{"session_id" => session_id}, socket) when is_binary(session_id) do
    cancel_identify_timer(socket)

    case SocketAuth.resolve(session_id) do
      {:ok, user_id} ->
        push(socket, "welcome", welcome_payload())

        {:reply, :ok,
         socket
         |> assign(:user_id, user_id)
         |> assign(:authenticated?, true)}

      {:error, :unauthorized} ->
        push(socket, "error", %{message: "인증이 필요합니다"})
        {:reply, {:error, %{reason: "unauthorized"}}, socket}
    end
  end

  def handle_in("identify", _payload, socket) do
    push(socket, "error", %{message: "session_id가 필요합니다"})
    {:reply, {:error, %{reason: "invalid_payload"}}, socket}
  end

  @impl true
  def handle_info(:identify_timeout, socket) do
    if socket.assigns[:user_id] do
      {:noreply, socket}
    else
      push(socket, "error", %{message: "identify 시간이 초과되었습니다"})
      {:stop, :normal, socket}
    end
  end

  defp cancel_identify_timer(%{assigns: %{identify_timer: ref}} = socket) when is_reference(ref) do
    Process.cancel_timer(ref)
    assign(socket, :identify_timer, nil)
  end

  defp cancel_identify_timer(socket), do: socket

  defp welcome_payload do
    app = :minesweeper_backend

    %{
      pingInterval: Application.get_env(app, :socket_ping_interval_ms, 10_000),
      pongTimeout: Application.get_env(app, :socket_pong_timeout_ms, 3_000)
    }
  end
end
