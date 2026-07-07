defmodule MinesweeperBackendWeb.Plugs.WsUpgrade do
  @moduledoc false

  import Plug.Conn

  def init(opts), do: opts

  def call(%{request_path: "/socket"} = conn, _opts) do
    if websocket_request?(conn) do
      WebSockAdapter.upgrade(conn, MinesweeperBackendWeb.WsHandler, %{}, timeout: :infinity)
    else
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(426, "Upgrade Required")
      |> halt()
    end
  end

  def call(conn, _opts), do: conn

  defp websocket_request?(conn) do
    conn = fetch_headers(conn)

    upgrade? =
      conn.req_headers
      |> Enum.any?(fn {k, v} -> String.downcase(k) == "upgrade" and String.downcase(v) == "websocket" end)

    connection? =
      conn.req_headers
      |> Enum.any?(fn {k, v} ->
        String.downcase(k) == "connection" and String.contains?(String.downcase(v), "upgrade")
      end)

    upgrade? and connection?
  end
end
