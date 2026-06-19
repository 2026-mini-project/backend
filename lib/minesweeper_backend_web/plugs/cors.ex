defmodule MinesweeperBackendWeb.Plugs.CORS do
  @moduledoc false

  import Plug.Conn

  @allowed_methods "GET, POST, PUT, PATCH, DELETE, OPTIONS"
  @allowed_headers "authorization, content-type, accept, x-requested-with"
  @max_age "86400"

  def init(opts), do: opts

  def call(conn, _opts) do
    case allowed_origin(conn) do
      nil ->
        conn

      origin ->
        conn
        |> put_cors_headers(origin)
        |> maybe_handle_preflight()
    end
  end

  defp allowed_origin(conn) do
    origin = conn |> get_req_header("origin") |> List.first()
    allowed_origins = Application.get_env(:minesweeper_backend, :cors_allowed_origins, ["*"])

    cond do
      origin == nil -> nil
      "*" in allowed_origins -> "*"
      origin in allowed_origins -> origin
      true -> nil
    end
  end

  defp put_cors_headers(conn, origin) do
    conn
    |> put_resp_header("access-control-allow-origin", origin)
    |> put_resp_header("access-control-allow-methods", @allowed_methods)
    |> put_resp_header("access-control-allow-headers", @allowed_headers)
    |> put_resp_header("access-control-max-age", @max_age)
    |> put_resp_header("vary", "origin")
  end

  defp maybe_handle_preflight(%{method: "OPTIONS"} = conn) do
    conn
    |> send_resp(:no_content, "")
    |> halt()
  end

  defp maybe_handle_preflight(conn), do: conn
end
