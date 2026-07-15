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

  def delete_room(room_id), do: GenServer.call(__MODULE__, {:delete_room, room_id})

  def cleanup_stale_empty_rooms,
    do: GenServer.call(__MODULE__, :cleanup_stale_empty_rooms)

  def fetch_game_settings(room_id),
    do: GenServer.call(__MODULE__, {:fetch_game_settings, room_id})

  def put_game_settings(room_id, settings),
    do: GenServer.call(__MODULE__, {:put_game_settings, room_id, settings})

  def fetch_game(room_id), do: GenServer.call(__MODULE__, {:fetch_game, room_id})
  def put_game(room_id, game), do: GenServer.call(__MODULE__, {:put_game, room_id, game})
  def delete_game(room_id), do: GenServer.call(__MODULE__, {:delete_game, room_id})

  def update_game(room_id, fun) when is_function(fun, 1),
    do: GenServer.call(__MODULE__, {:update_game, room_id, fun})

  @impl true
  def init(_) do
    {:ok,
     %{
       users: %{},
       sessions: %{},
       rooms: %{},
       members: %{},
       ready: %{},
       game_settings: %{},
       games: %{}
     }}
  end

  @impl true
  def handle_call({:create_user, attrs}, _from, state) do
    state = evict_expired(state)
    attrs = Map.put(attrs, "expires_at", future_expiration())

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
    state = evict_expired(state)
    {:reply, nickname_taken?(state, name), state}
  end

  def handle_call({:fetch_user, id}, _from, state) do
    state = evict_expired(state)
    user_id = Map.get(state.sessions, id, id)
    {:reply, Map.fetch(state.users, user_id), state}
  end

  def handle_call({:refresh_session, id}, _from, state) do
    state = evict_expired(state)

    case Map.fetch(state.users, id) do
      {:ok, user} ->
        refreshed = %{user | expires_at: future_expiration()}

        state =
          state
          |> put_in([:users, id], refreshed)
          |> put_in([:sessions, id], id)

        {:reply, :ok, state}

      :error ->
        {:reply, {:error, :unauthorized}, state}
    end
  end

  def handle_call({:delete_session, id}, _from, state) do
    state = evict_expired(state)

    if Map.has_key?(state.users, id) do
      state =
        state
        |> update_in([:users], &Map.delete(&1, id))
        |> update_in([:sessions], &Map.delete(&1, id))
        |> remove_user_from_sets(:members, id)
        |> remove_user_from_sets(:ready, id)
        |> drop_owned_rooms(id)
        |> drop_empty_rooms()

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
    state =
      update_in(state, [:members, room_id], &MapSet.put(&1 || MapSet.new(), user_id))

    {:reply, :ok, state}
  end

  def handle_call({:list_members, room_id}, _from, state) do
    members = state.members |> Map.get(room_id, MapSet.new()) |> MapSet.to_list()
    {:reply, members, state}
  end

  def handle_call({:remove_member, room_id, user_id}, _from, state) do
    members =
      state.members
      |> Map.get(room_id, MapSet.new())
      |> MapSet.delete(user_id)

    state =
      state
      |> put_in([:members, room_id], members)
      |> drop_room_if_empty(room_id, members)

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

  def handle_call({:delete_room, room_id}, _from, state) do
    {:reply, :ok, drop_room(state, room_id)}
  end

  def handle_call(:cleanup_stale_empty_rooms, _from, state) do
    {:reply, :ok, drop_empty_rooms(state)}
  end

  def handle_call({:fetch_game_settings, room_id}, _from, state) do
    {:reply, Map.fetch(state.game_settings, room_id), state}
  end

  def handle_call({:put_game_settings, room_id, settings}, _from, state) do
    if Map.has_key?(state.rooms, room_id) do
      {:reply, :ok, put_in(state, [:game_settings, room_id], settings)}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:fetch_game, room_id}, _from, state) do
    {:reply, Map.fetch(state.games, room_id), state}
  end

  def handle_call({:put_game, room_id, game}, _from, state) do
    {:reply, :ok, put_in(state, [:games, room_id], game)}
  end

  def handle_call({:delete_game, room_id}, _from, state) do
    {:reply, :ok, update_in(state, [:games], &Map.delete(&1, room_id))}
  end

  def handle_call({:update_game, room_id, fun}, _from, state) do
    case Map.fetch(state.games, room_id) do
      {:ok, game} ->
        updated = fun.(game)
        {:reply, {:ok, updated}, put_in(state, [:games, room_id], updated)}

      :error ->
        {:reply, :error, state}
    end
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
    now = DateTime.utc_now()

    Enum.any?(state.users, fn {_id, %User{expires_at: exp, name: n}} ->
      n == name and DateTime.compare(exp, now) == :gt
    end)
  end

  defp evict_expired(state) do
    now = DateTime.utc_now()

    expired_ids =
      state.users
      |> Enum.filter(fn {_id, %User{expires_at: exp}} ->
        DateTime.compare(exp, now) != :gt
      end)
      |> Enum.map(&elem(&1, 0))

    Enum.reduce(expired_ids, state, fn id, acc ->
      acc
      |> update_in([:users], &Map.delete(&1, id))
      |> update_in([:sessions], &Map.delete(&1, id))
      |> remove_user_from_sets(:members, id)
      |> remove_user_from_sets(:ready, id)
      |> drop_owned_rooms(id)
      |> drop_empty_rooms()
    end)
  end

  defp drop_owned_rooms(state, owner_id) do
    state.rooms
    |> Enum.filter(fn {_id, %Room{owner_id: oid}} -> oid == owner_id end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.reduce(state, &drop_room/2)
  end

  defp future_expiration do
    ttl = Application.get_env(:minesweeper_backend, :session_ttl_seconds, 3_600)
    DateTime.utc_now() |> DateTime.add(ttl, :second)
  end

  defp remove_user_from_sets(state, key, user_id) do
    update_in(state, [key], fn sets ->
      Map.new(sets, fn {id, user_ids} -> {id, MapSet.delete(user_ids, user_id)} end)
    end)
  end

  defp drop_room_if_empty(state, room_id, members) do
    if MapSet.size(members) == 0 do
      drop_room(state, room_id)
    else
      state
    end
  end

  defp drop_empty_rooms(state) do
    state.rooms
    |> Map.keys()
    |> Enum.filter(fn room_id ->
      state.members
      |> Map.get(room_id, MapSet.new())
      |> MapSet.size()
      |> Kernel.==(0)
    end)
    |> Enum.reduce(state, fn room_id, acc -> drop_room(acc, room_id) end)
  end

  defp drop_room(state, room_id) do
    state
    |> update_in([:rooms], &Map.delete(&1, room_id))
    |> update_in([:members], &Map.delete(&1, room_id))
    |> update_in([:ready], &Map.delete(&1, room_id))
    |> update_in([:game_settings], &Map.delete(&1, room_id))
    |> update_in([:games], &Map.delete(&1, room_id))
  end
end
