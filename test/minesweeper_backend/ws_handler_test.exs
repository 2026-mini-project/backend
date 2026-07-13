defmodule MinesweeperBackendWeb.WsHandlerTest do
  use ExUnit.Case, async: false

  alias MinesweeperBackend.{Accounts, Rooms}
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
end
