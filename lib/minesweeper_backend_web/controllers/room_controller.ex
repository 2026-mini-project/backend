defmodule MinesweeperBackendWeb.RoomController do
  use MinesweeperBackendWeb, :controller

  alias MinesweeperBackend.Rooms
  alias MinesweeperBackendWeb.{FallbackController, RoomJSON}

  action_fallback FallbackController

  def show(conn, %{"id" => id}) do
    with {:ok, room} <- Rooms.fetch_room(id) do
      conn
      |> put_view(json: RoomJSON)
      |> render(:show, room: room, full: Rooms.full?(room))
    end
  end

  def create(conn, params) do
    user = conn.assigns.current_user

    with {:ok, name} <- fetch_name(params),
         {:ok, room} <- Rooms.create_room(user.id, %{"name" => name}) do
      conn
      |> put_status(:created)
      |> put_view(json: RoomJSON)
      |> render(:show, room: room, full: Rooms.full?(room))
    end
  end

  defp fetch_name(%{"name" => name}) when is_binary(name) and name != "", do: {:ok, name}
  defp fetch_name(_), do: {:error, "name is required"}
end
