defmodule MinesweeperBackendWeb.SessionController do
  use MinesweeperBackendWeb, :controller

  alias MinesweeperBackend.Accounts
  alias MinesweeperBackendWeb.{FallbackController, SessionJSON}

  action_fallback FallbackController

  def show(conn, _params) do
    user = conn.assigns.current_user

    conn
    |> put_view(json: SessionJSON)
    |> render(:show, user: user)
  end

  def create(conn, params) do
    with {:ok, name} <- fetch_name(params),
         {:ok, user} <- Accounts.create_session(%{name: name}) do
      conn
      |> put_status(:created)
      |> put_view(json: SessionJSON)
      |> render(:show, user: user)
    end
  end

  defp fetch_name(%{"name" => name}) when is_binary(name) and name != "", do: {:ok, name}
  defp fetch_name(_), do: {:error, "name is required"}
end
