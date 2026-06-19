defmodule MinesweeperBackend.MemoryStore do
  @moduledoc false

  use GenServer

  alias MinesweeperBackend.Accounts.User
  alias MinesweeperBackend.Rooms.Room

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def create_user(attrs), do: GenServer.call(__MODULE__, {:create_user, attrs})
  def nickname_taken?(name), do: GenServer.call(__MODULE__, {:nickname_taken?, name})
  def fetch_user(id), do: GenServer.call(__MODULE__, {:fetch_user, id})
  def refresh_session(id), do: GenServer.call(__MODULE__, {:refresh_session, id})
  def delete_session(id), do: GenServer.call(__MODULE__, {:delete_session, id})

  def create_room(owner_id, attrs),
    do: GenServer.call(__MODULE__, {:create_room, owner_id, attrs})

  def list_public_rooms, do: GenServer.call(__MODULE__, :list_public_rooms)
  def fetch_room(id), do: GenServer.call(__MODULE__, {:fetch_room, id})
  def room_full?(id), do: GenServer.call(__MODULE__, {:room_full?, id})

  def add_member(room_id, user_id),
    do: GenServer.call(__MODULE__, {:add_member, room_id, user_id})

  def list_members(room_id), do: GenServer.call(__MODULE__, {:list_members, room_id})

  def remove_member(room_id, user_id),
    do: GenServer.call(__MODULE__, {:remove_member, room_id, user_id})

  def list_ready(room_id), do: GenServer.call(__MODULE__, {:list_ready, room_id})

  def mark_ready(room_id, user_id),
    do: GenServer.call(__MODULE__, {:mark_ready, room_id, user_id})

  def cancel_ready(room_id, user_id),
    do: GenServer.call(__MODULE__, {:cancel_ready, room_id, user_id})

  @impl true
  def init(_) do
    {:ok, %{users: %{}, sessions: %{}, rooms: %{}, members: %{}, ready: %{}}}
  end

  @impl true
  def handle_call({:create_user, attrs}, _from, state) do
    with false <- nickname_taken?(state, attrs["name"]),
         {:ok, user} <- build_user(attrs) do
      state =
        state
        |> put_in([:users, user.id], user)
        |> put_in([:sessions, user.id], user.id)

      {:reply, {:ok, user}, state}
    else
      true -> {:reply, {:error, "이미 사용 중인 닉네임입니다"}, state}
      error -> {:reply, error, state}
    end
  end

  def handle_call({:nickname_taken?, name}, _from, state) do
    {:reply, nickname_taken?(state, name), state}
  end

  def handle_call({:fetch_user, id}, _from, state) do
    user_id = Map.get(state.sessions, id, id)
    {:reply, Map.fetch(state.users, user_id), state}
  end

  def handle_call({:refresh_session, id}, _from, state) do
    if Map.has_key?(state.users, id) do
      {:reply, :ok, put_in(state, [:sessions, id], id)}
    else
      {:reply, {:error, :unauthorized}, state}
    end
  end

  def handle_call({:delete_session, id}, _from, state) do
    if Map.has_key?(state.users, id) do
      state =
        state
        |> update_in([:users], &Map.delete(&1, id))
        |> update_in([:sessions], &Map.delete(&1, id))
        |> remove_user_from_sets(:members, id)
        |> remove_user_from_sets(:ready, id)

      {:reply, :ok, state}
    else
      {:reply, {:error, :unauthorized}, state}
    end
  end

  def handle_call({:create_room, owner_id, attrs}, _from, state) do
    with true <- Map.has_key?(state.users, owner_id),
         {:ok, room} <- build_room(owner_id, attrs) do
      state =
        state
        |> put_in([:rooms, room.id], room)
        |> update_in([:members, room.id], &MapSet.put(&1 || MapSet.new(), owner_id))

      {:reply, {:ok, room}, state}
    else
      false -> {:reply, {:error, :unauthorized}, state}
      error -> {:reply, error, state}
    end
  end

  def handle_call(:list_public_rooms, _from, state) do
    rooms =
      state.rooms
      |> Map.values()
      |> Enum.reject(& &1.is_private)
      |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})

    {:reply, rooms, state}
  end

  def handle_call({:fetch_room, id}, _from, state) do
    case Map.fetch(state.rooms, id) do
      {:ok, room} -> {:reply, {:ok, room}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:room_full?, id}, _from, state) do
    room = Map.get(state.rooms, id)
    count = state.members |> Map.get(id, MapSet.new()) |> MapSet.size()
    {:reply, !!room && count >= room.max_players, state}
  end

  def handle_call({:add_member, room_id, user_id}, _from, state) do
    state = update_in(state, [:members, room_id], &MapSet.put(&1 || MapSet.new(), user_id))
    {:reply, :ok, state}
  end

  def handle_call({:list_members, room_id}, _from, state) do
    members = state.members |> Map.get(room_id, MapSet.new()) |> MapSet.to_list()
    {:reply, members, state}
  end

  def handle_call({:remove_member, room_id, user_id}, _from, state) do
    state = update_in(state, [:members, room_id], &MapSet.delete(&1 || MapSet.new(), user_id))
    {:reply, :ok, state}
  end

  def handle_call({:list_ready, room_id}, _from, state) do
    ready = state.ready |> Map.get(room_id, MapSet.new()) |> MapSet.to_list()
    {:reply, ready, state}
  end

  def handle_call({:mark_ready, room_id, user_id}, _from, state) do
    state = update_in(state, [:ready, room_id], &MapSet.put(&1 || MapSet.new(), user_id))
    {:reply, :ok, state}
  end

  def handle_call({:cancel_ready, room_id, user_id}, _from, state) do
    state = update_in(state, [:ready, room_id], &MapSet.delete(&1 || MapSet.new(), user_id))
    {:reply, :ok, state}
  end

  defp build_user(attrs) do
    %User{id: Ecto.UUID.generate()}
    |> User.changeset(attrs)
    |> Ecto.Changeset.apply_action(:insert)
    |> timestamp()
  end

  defp build_room(owner_id, attrs) do
    attrs =
      attrs
      |> Map.put_new("owner_id", owner_id)
      |> Map.put_new(
        "max_players",
        Application.get_env(:minesweeper_backend, :room_max_players, 2)
      )
      |> normalize_private_attr()

    %Room{id: Ecto.UUID.generate()}
    |> Room.changeset(attrs)
    |> Ecto.Changeset.apply_action(:insert)
    |> timestamp()
  end

  defp timestamp({:ok, struct}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    {:ok, %{struct | inserted_at: now, updated_at: now}}
  end

  defp timestamp(error), do: error

  defp normalize_private_attr(%{"private" => private} = attrs) do
    attrs
    |> Map.delete("private")
    |> Map.put("is_private", private)
  end

  defp normalize_private_attr(attrs), do: attrs

  defp nickname_taken?(state, name) do
    Enum.any?(state.users, fn {_id, user} -> user.name == name end)
  end

  defp remove_user_from_sets(state, key, user_id) do
    update_in(state, [key], fn sets ->
      Map.new(sets, fn {id, user_ids} -> {id, MapSet.delete(user_ids, user_id)} end)
    end)
  end
end
