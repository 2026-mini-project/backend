defmodule MinesweeperBackendWeb.Plugs.Authenticate do
  @moduledoc """
  Reads the `Authorization` header (treated as a raw session id),
  resolves it via `MinesweeperBackend.Accounts`, and stuffs the
  resulting `%User{}` into `conn.assigns[:current_user]`.

  On failure it short-circuits with `401 {"message": "..."}` exactly
  the way the README requires errors to look.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias MinesweeperBackend.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    session_id = extract_token(conn)

    case Accounts.fetch_user_by_session(session_id) do
      {:ok, user} ->
        assign(conn, :current_user, user)

      {:error, _} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{message: "인증이 필요합니다"})
        |> halt()
    end
  end

  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      [value | _] -> value |> String.trim() |> strip_bearer()
      _ -> nil
    end
  end

  defp strip_bearer(<<"Bearer ", rest::binary>>), do: rest
  defp strip_bearer(<<"bearer ", rest::binary>>), do: rest
  defp strip_bearer(other), do: other
end
