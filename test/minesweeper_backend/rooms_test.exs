defmodule MinesweeperBackend.RoomsTest do
  use ExUnit.Case, async: false

  alias MinesweeperBackend.{Accounts, Rooms}
  alias MinesweeperBackendWeb.RoomJSON

  setup do
    :ok
  end

  defp create_user!(name) do
    {:ok, user} = Accounts.create_session(%{"name" => name})
    user
  end

  defp create_room!(owner, name \\ "test-room") do
    {:ok, room} = Rooms.create_room(owner.id, %{"name" => name, "private" => false})
    room
  end

  test "owner field in API response is nickname not session id" do
    user = create_user!("player-one")
    room = create_room!(user)

    json = RoomJSON.show(%{room: room, full: false})

    assert json.owner == "player-one"
    refute json.owner == user.id
  end

  test "empty room is deleted after cleanup when ttl elapsed" do
    user = create_user!("leaver")
    room = create_room!(leaver = user)

    assert {:ok, _} = Rooms.fetch_room(room.id)
    assert :ok = Rooms.remove_member(room.id, leaver.id)
    assert Rooms.list_members(room.id) == []

    assert :ok = Rooms.cleanup_stale_empty_rooms()
    assert {:error, :not_found} = Rooms.fetch_room(room.id)
  end

  test "rejoining clears empty mark and prevents deletion" do
    owner = create_user!("owner-one")
    guest = create_user!("guest-two")
    room = create_room!(owner)

    assert :ok = Rooms.add_member(room.id, guest.id)
    assert :ok = Rooms.remove_member(room.id, owner.id)
    assert :ok = Rooms.remove_member(room.id, guest.id)

    assert :ok = Rooms.add_member(room.id, owner.id)
    assert :ok = Rooms.cleanup_stale_empty_rooms()
    assert {:ok, _} = Rooms.fetch_room(room.id)
  end
end
