defmodule MinesweeperBackend.Rooms do
  @moduledoc """
  Rooms context backed by in-memory storage.

  Live membership and ready state live in `MemoryStore`. Game state is
  also stored in `MemoryStore`.
  """

  alias MinesweeperBackend.{Game, MemoryStore}
  alias MinesweeperBackend.Rooms.Room

  def create_room(owner_id, attrs) when is_binary(owner_id) do
    MemoryStore.create_room(owner_id, attrs)
  end

  def list_public_rooms, do: MemoryStore.list_public_rooms()

  def fetch_room(id) when is_binary(id), do: MemoryStore.fetch_room(id)

  def full?(%Room{id: id}), do: MemoryStore.room_full?(id)

  def add_member(room_id, user_id), do: MemoryStore.add_member(room_id, user_id)
  def list_members(room_id), do: MemoryStore.list_members(room_id)
  def remove_member(room_id, user_id), do: MemoryStore.remove_member(room_id, user_id)
  def list_ready(room_id), do: MemoryStore.list_ready(room_id)
  def mark_ready(room_id, user_id), do: MemoryStore.mark_ready(room_id, user_id)
  def cancel_ready(room_id, user_id), do: MemoryStore.cancel_ready(room_id, user_id)
  def cleanup_stale_empty_rooms, do: MemoryStore.cleanup_stale_empty_rooms()

  def delete_room(room_id) when is_binary(room_id) do
    :ok = Game.clear(room_id)
    MemoryStore.delete_room(room_id)
  end
end
