defmodule MinesweeperBackendWeb.RoomJSON do
  alias MinesweeperBackend.Rooms.Room

  @doc """
  Renders APIRoom:

      type APIRoom = {
        "id": string,
        "name": string,
        "owner": string,   // SessionId
        "private": boolean,
        "full": boolean
      };
  """
  def index(%{rooms: rooms, full?: full?}) do
    Enum.map(rooms, &room_json(&1, full?.(&1)))
  end

  def show(%{room: %Room{} = room, full: full}) do
    room_json(room, full)
  end

  defp room_json(%Room{} = room, full) do
    %{
      id: room.id,
      name: room.name,
      owner: room.owner_id,
      private: room.is_private,
      full: full
    }
  end
end
