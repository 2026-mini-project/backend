defmodule MinesweeperBackendWeb.RoomJSON do
  alias MinesweeperBackend.Rooms.Room

  @doc """
  Renders APIRoom:

      type APIRoom = {
        "id": string,
        "name": string,
        "owner": string,   // SessionId
        "full": boolean
      };
  """
  def show(%{room: %Room{} = room, full: full}) do
    %{
      id: room.id,
      name: room.name,
      owner: room.owner_id,
      full: full
    }
  end
end
