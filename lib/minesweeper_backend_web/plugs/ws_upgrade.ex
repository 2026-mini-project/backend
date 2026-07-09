defmodule MinesweeperBackendWeb.Plugs.WsUpgrade do
  @moduledoc false

  import Plug.Conn

  def init(opts), do: opts

  def call(%{request_path: "/socket"} = conn, _opts) do
    if websocket_request?(conn) do
      conn
      |> WebSockAdapter.upgrade(MinesweeperBackendWeb.WsHandler, %{}, timeout: :infinity)
      |> halt()
    else
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(426, "Upgrade Required")
      |> halt()
    end
  end

  def call(conn, _opts), do: conn

  defp websocket_request?(conn) do
    upgrade? =
      conn
      |> get_req_header("upgrade")
      |> Enum.any?(&(String.downcase(&1) == "websocket"))

    connection? =
      conn
      |> get_req_header("connection")
      |> Enum.any?(&String.contains?(String.downcase(&1), "upgrade"))

    upgrade? and connection?
  end
end
