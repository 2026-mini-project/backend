defmodule MinesweeperBackendWeb.RoomJSON do
  alias MinesweeperBackend.Accounts
  alias MinesweeperBackend.Accounts.User
  alias MinesweeperBackend.Rooms.Room

  @doc """
  Renders APIRoom:

      type APIRoom = {
        "id": string,
        "name": string,
        "owner": string,   // owner nickname
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
      owner: owner_name(room),
      private: room.is_private,
      full: full
    }
  end

  defp owner_name(%Room{owner: %User{name: name}}) when is_binary(name), do: name

  defp owner_name(%Room{owner_id: owner_id}) do
    case Accounts.fetch_user_by_session(owner_id) do
      {:ok, %{name: name}} -> name
      _ -> nil
    end
  end
end
