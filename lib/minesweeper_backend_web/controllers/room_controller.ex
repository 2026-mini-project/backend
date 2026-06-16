defmodule MinesweeperBackendWeb.RoomController do
  use MinesweeperBackendWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias MinesweeperBackend.Rooms
  alias MinesweeperBackendWeb.API.{APIError, APIRoom, CreateRoomRequest}
  alias MinesweeperBackendWeb.{FallbackController, RoomJSON}

  action_fallback FallbackController

  operation :show,
    tags: ["rooms"],
    summary: "Fetch a room by id",
    operation_id: "getRoom",
    security: [%{"SessionId" => []}],
    parameters: [
      id: [
        in: :path,
        required: true,
        description: "Room UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid}
      ]
    ],
    responses: [
      ok: %OpenApiSpex.Response{
        description: "Room details",
        content: %{"application/json" => %OpenApiSpex.MediaType{schema: APIRoom}}
      },
      not_found: %OpenApiSpex.Response{
        description: "Room not found",
        content: %{"application/json" => %OpenApiSpex.MediaType{schema: APIError}}
      },
      unauthorized: %OpenApiSpex.Response{
        description: "No or invalid session",
        content: %{"application/json" => %OpenApiSpex.MediaType{schema: APIError}}
      }
    ]

  operation :create,
    tags: ["rooms"],
    summary: "Create a new room",
    operation_id: "createRoom",
    security: [%{"SessionId" => []}],
    request_body:
      {"Request body", "application/json", CreateRoomRequest, required: true},
    responses: [
      created: %OpenApiSpex.Response{
        description: "Room created",
        content: %{"application/json" => %OpenApiSpex.MediaType{schema: APIRoom}}
      },
      bad_request: %OpenApiSpex.Response{
        description: "Validation failed",
        content: %{"application/json" => %OpenApiSpex.MediaType{schema: APIError}}
      },
      unauthorized: %OpenApiSpex.Response{
        description: "No or invalid session",
        content: %{"application/json" => %OpenApiSpex.MediaType{schema: APIError}}
      }
    ]

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
