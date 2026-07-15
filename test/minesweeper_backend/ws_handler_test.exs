defmodule MinesweeperBackendWeb.WsHandlerTest do
  use ExUnit.Case, async: false

  alias MinesweeperBackend.{Accounts, Game, Rooms}
  alias MinesweeperBackendWeb.WsHandler

  setup do
    on_exit(fn ->
      for {key, _} <- Registry.lookup(MinesweeperBackendWeb.RoomRegistry, :_) do
        Registry.unregister(MinesweeperBackendWeb.RoomRegistry, key)
      end
    end)

    :ok
  end

  test "identify and join room" do
    {:ok, user} = Accounts.create_session(%{"name" => "wsplayer"})
    {:ok, room} = Rooms.create_room(user.id, %{"name" => "wstest", "private" => false})

    assert {:ok, state} = WsHandler.init(%{})
    state = drain_timer_messages(state)

    assert {:push, frames, state} =
             WsHandler.handle_in(
               {Jason.encode!(["identify", %{"sessionId" => user.id}]), opcode: :text},
               state
             )

    assert Enum.any?(frames, fn {:text, raw} ->
             match?({:ok, ["welcome", _]}, Jason.decode(raw))
           end)

    assert state.user_id == user.id

    assert {:ok, state} =
             WsHandler.handle_in(
               {Jason.encode!(["join", %{"id" => room.id}]), opcode: :text},
               state
             )

    assert state.room_id == room.id

    assert {:push, frames, _state} =
             WsHandler.handle_info({:room_push, "joined", joined_users(room.id)}, state)

    assert Enum.any?(frames, fn {:text, raw} ->
             match?({:ok, ["joined", _]}, Jason.decode(raw))
           end)
  end

  test "disconnect deletes a room when the last member leaves" do
    {:ok, user} = Accounts.create_session(%{"name" => "disconnect-player"})
    {:ok, room} = Rooms.create_room(user.id, %{"name" => "disconnect-room", "private" => false})

    assert :ok =
             WsHandler.terminate(:normal, %{
               user_id: user.id,
               room_id: room.id,
               identify_timer: nil
             })

    assert {:error, :not_found} = Rooms.fetch_room(room.id)
  end

  test "flag broadcasts the same payload shape as boardClick to room members" do
    {:ok, owner} = Accounts.create_session(%{"name" => "flag-owner"})
    {:ok, guest} = Accounts.create_session(%{"name" => "flag-guest"})
    {:ok, room} = Rooms.create_room(owner.id, %{"name" => "flag-room", "private" => false})
    :ok = Rooms.add_member(room.id, guest.id)

    [current_user_id, next_user_id] = Enum.sort([owner.id, guest.id])
    {:ok, _game} = Game.start_game(room.id, [owner.id, guest.id])

    recipient_user_id = if current_user_id == owner.id, do: guest.id, else: owner.id
    test_pid = self()

    recipient_pid =
      spawn_link(fn ->
        Registry.register(
          MinesweeperBackendWeb.RoomRegistry,
          {room.id, recipient_user_id},
          nil
        )

        send(test_pid, :recipient_registered)
        forward_room_pushes(test_pid)
      end)

    assert_receive :recipient_registered

    state = %{user_id: current_user_id, room_id: room.id, identify_timer: nil}
    payload = %{"x" => 2, "y" => 3}

    assert {:push, [{:text, raw}], ^state} =
             WsHandler.handle_in({Jason.encode!(["flag", payload]), opcode: :text}, state)

    assert Jason.decode!(raw) == ["flag", %{"x" => 2, "y" => 3, "by" => current_user_id}]

    assert_receive {:recipient_push, "flag", broadcast_payload}
    assert broadcast_payload == %{x: 2, y: 3, by: current_user_id}
    assert_receive {:recipient_push, "turn", %{userId: ^next_user_id}}

    send(recipient_pid, :stop)
  end

  test "owner can configure the board and receives done" do
    {:ok, owner} = Accounts.create_session(%{"name" => "settings-owner"})
    {:ok, guest} = Accounts.create_session(%{"name" => "settings-guest"})

    {:ok, room} =
      Rooms.create_room(owner.id, %{"name" => "settings-room", "private" => false})

    :ok = Rooms.add_member(room.id, guest.id)

    state = %{user_id: owner.id, room_id: room.id, identify_timer: nil}
    payload = %{"mines" => 7, "size" => 6}

    assert {:push, [{:text, raw}], ^state} =
             WsHandler.handle_in({Jason.encode!(["settings", payload]), opcode: :text}, state)

    assert Jason.decode!(raw) == ["done"]
    assert Game.settings(room.id) == %{mines: 7, size: 6}

    assert {:ok, game} = Game.start_game(room.id, [owner.id, guest.id])
    assert game.board_size == 6
    assert game.mine_count == 7

    assert {:ok, decoded} = Game.decode_board(game.board)

    assert decoded
           |> :binary.bin_to_list()
           |> Enum.take(36)
           |> Enum.count(&(&1 == 1)) == 7
  end

  defp joined_users(room_id) do
    Rooms.list_members(room_id)
    |> Enum.map(fn id ->
      {:ok, user} = Accounts.fetch_user_by_session(id)
      %{id: user.id, name: user.name}
    end)
  end

  defp drain_timer_messages(state) do
    receive do
      :identify_timeout -> drain_timer_messages(state)
    after
      0 -> state
    end
  end

  defp forward_room_pushes(test_pid) do
    receive do
      {:room_push, event, payload} ->
        send(test_pid, {:recipient_push, event, payload})
        forward_room_pushes(test_pid)

      :stop ->
        :ok
    end
  end
end
