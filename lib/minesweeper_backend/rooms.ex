defmodule MinesweeperBackend.Rooms do
  @moduledoc """
  Rooms context.

  Postgres stores `rooms` rows (id, name, owner_id, max_players).
  Redis stores live membership in a SET per room
  (`room:<room_id>:members`). `full?/1` compares the SET cardinality
  to `max_players`.

  When the WebSocket layer is added later, joining / leaving a room
  just becomes `SADD` / `SREM` against the same set – no schema change.
  """

  alias MinesweeperBackend.{MemoryStore, Repo, Redix}
  alias MinesweeperBackend.Rooms.Room
  import Ecto.Query

  @members_prefix "room:"
  @members_suffix ":members"
  @ready_prefix "room:"
  @ready_suffix ":ready"

  @doc """
  Creates a room owned by `owner_id`. The owner is immediately added
  to the membership set in Redis.
  """
  def create_room(owner_id, attrs) when is_binary(owner_id) do
    if memory_storage?(),
      do: MemoryStore.create_room(owner_id, attrs),
      else: create_room_with_repo(owner_id, attrs)
  end

  defp create_room_with_repo(owner_id, attrs) do
    max_players = Application.get_env(:minesweeper_backend, :room_max_players, 2)

    full_attrs =
      attrs
      |> Map.put_new("owner_id", owner_id)
      |> Map.put_new("max_players", max_players)
      |> normalize_private_attr()

    %Room{}
    |> Room.changeset(full_attrs)
    |> Repo.insert()
    |> case do
      {:ok, room} ->
        :ok = add_member(room.id, owner_id)
        {:ok, room}

      error ->
        error
    end
  end

  @doc "Lists public rooms ordered from newest to oldest."
  def list_public_rooms do
    if memory_storage?(), do: MemoryStore.list_public_rooms(), else: list_public_rooms_with_repo()
  end

  defp list_public_rooms_with_repo do
    Room
    |> where([room], room.is_private == false)
    |> order_by([room], desc: room.inserted_at)
    |> Repo.all()
  end

  @doc "Fetches a room by id. Returns `{:ok, room}` or `{:error, :not_found}`."
  def fetch_room(id) when is_binary(id) do
    if memory_storage?(), do: MemoryStore.fetch_room(id), else: fetch_room_with_repo(id)
  end

  defp fetch_room_with_repo(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        case Repo.get(Room, uuid) do
          nil -> {:error, :not_found}
          %Room{} = room -> {:ok, room}
        end

      :error ->
        {:error, :not_found}
    end
  end

  @doc """
  Returns `true` if the room's membership set has at least
  `max_players` members.
  """
  def full?(%Room{id: id, max_players: max}) do
    if memory_storage?() do
      MemoryStore.room_full?(id)
    else
      full_with_redis?(id, max)
    end
  end

  defp full_with_redis?(id, max) do
    case Redix.command(["SCARD", members_key(id)]) do
      {:ok, count} when is_integer(count) -> count >= max
      _ -> false
    end
  end

  @doc "Adds a session/user to a room's membership set."
  def add_member(room_id, user_id) do
    if memory_storage?(),
      do: MemoryStore.add_member(room_id, user_id),
      else: add_redis_member(room_id, user_id)
  end

  defp add_redis_member(room_id, user_id) do
    case Redix.command(["SADD", members_key(room_id), user_id]) do
      {:ok, _} -> :ok
      _ -> :ok
    end
  end

  @doc "Lists the session/user ids currently in a room's membership set."
  def list_members(room_id) do
    if memory_storage?(), do: MemoryStore.list_members(room_id), else: list_redis_members(room_id)
  end

  defp list_redis_members(room_id) do
    case Redix.command(["SMEMBERS", members_key(room_id)]) do
      {:ok, members} when is_list(members) -> members
      _ -> []
    end
  end

  @doc "Removes a session/user from a room's membership set."
  def remove_member(room_id, user_id) do
    if memory_storage?(),
      do: MemoryStore.remove_member(room_id, user_id),
      else: remove_redis_member(room_id, user_id)
  end

  defp remove_redis_member(room_id, user_id) do
    case Redix.command(["SREM", members_key(room_id), user_id]) do
      {:ok, _} -> :ok
      _ -> :ok
    end
  end

  @doc "Lists the session ids currently marked as ready in a room."
  def list_ready(room_id) do
    if memory_storage?(), do: MemoryStore.list_ready(room_id), else: list_redis_ready(room_id)
  end

  defp list_redis_ready(room_id) do
    case Redix.command(["HKEYS", ready_key(room_id)]) do
      {:ok, keys} when is_list(keys) -> keys
      _ -> []
    end
  end

  @doc """
  Marks a session as ready in the given room. Returns `:ok` even on
  Redis failure (best-effort), matching the membership helpers.
  """
  def mark_ready(room_id, user_id) do
    if memory_storage?(),
      do: MemoryStore.mark_ready(room_id, user_id),
      else: mark_redis_ready(room_id, user_id)
  end

  defp mark_redis_ready(room_id, user_id) do
    case Redix.command(["HSET", ready_key(room_id), user_id, "1"]) do
      {:ok, _} -> :ok
      _ -> :ok
    end
  end

  @doc "Removes a session's ready flag in the given room."
  def cancel_ready(room_id, user_id) do
    if memory_storage?(),
      do: MemoryStore.cancel_ready(room_id, user_id),
      else: cancel_redis_ready(room_id, user_id)
  end

  defp cancel_redis_ready(room_id, user_id) do
    case Redix.command(["HDEL", ready_key(room_id), user_id]) do
      {:ok, _} -> :ok
      _ -> :ok
    end
  end

  defp members_key(room_id), do: @members_prefix <> room_id <> @members_suffix
  defp ready_key(room_id), do: @ready_prefix <> room_id <> @ready_suffix

  defp normalize_private_attr(%{"private" => private} = attrs) do
    attrs
    |> Map.delete("private")
    |> Map.put("is_private", private)
  end

  defp normalize_private_attr(attrs), do: attrs

  defp memory_storage? do
    Application.get_env(:minesweeper_backend, :storage_driver) == "memory"
  end
end
