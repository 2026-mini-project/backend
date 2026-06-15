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

  alias MinesweeperBackend.{Repo, Redix}
  alias MinesweeperBackend.Rooms.Room

  @members_prefix "room:"
  @members_suffix ":members"
  @ready_prefix "room:"
  @ready_suffix ":ready"

  @doc """
  Creates a room owned by `owner_id`. The owner is immediately added
  to the membership set in Redis.
  """
  def create_room(owner_id, attrs) when is_binary(owner_id) do
    max_players = Application.get_env(:minesweeper_backend, :room_max_players, 2)

    full_attrs =
      attrs
      |> Map.put_new("owner_id", owner_id)
      |> Map.put_new("max_players", max_players)

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

  @doc "Fetches a room by id. Returns `{:ok, room}` or `{:error, :not_found}`."
  def fetch_room(id) when is_binary(id) do
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
    case Redix.command(["SCARD", members_key(id)]) do
      {:ok, count} when is_integer(count) -> count >= max
      _ -> false
    end
  end

  @doc "Adds a session/user to a room's membership set."
  def add_member(room_id, user_id) do
    case Redix.command(["SADD", members_key(room_id), user_id]) do
      {:ok, _} -> :ok
      _ -> :ok
    end
  end

  @doc "Lists the session/user ids currently in a room's membership set."
  def list_members(room_id) do
    case Redix.command(["SMEMBERS", members_key(room_id)]) do
      {:ok, members} when is_list(members) -> members
      _ -> []
    end
  end

  @doc "Removes a session/user from a room's membership set."
  def remove_member(room_id, user_id) do
    case Redix.command(["SREM", members_key(room_id), user_id]) do
      {:ok, _} -> :ok
      _ -> :ok
    end
  end

  @doc "Lists the session ids currently marked as ready in a room."
  def list_ready(room_id) do
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
    case Redix.command(["HSET", ready_key(room_id), user_id, "1"]) do
      {:ok, _} -> :ok
      _ -> :ok
    end
  end

  @doc "Removes a session's ready flag in the given room."
  def cancel_ready(room_id, user_id) do
    case Redix.command(["HDEL", ready_key(room_id), user_id]) do
      {:ok, _} -> :ok
      _ -> :ok
    end
  end

  defp members_key(room_id), do: @members_prefix <> room_id <> @members_suffix
  defp ready_key(room_id), do: @ready_prefix <> room_id <> @ready_suffix
end
