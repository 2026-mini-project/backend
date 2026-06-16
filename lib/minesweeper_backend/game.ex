defmodule MinesweeperBackend.Game do
  @moduledoc """
  Game state lives entirely in Redis under `room:<room_id>:game`.

  Hash fields:

    * `board_size`     – integer, edge length of the square board
    * `mine_count`     – integer, number of mines
    * `board`          – Base85-encoded bitstring (`"1"` = mine, `"0"` = empty)
    * `current_turn`   – user_id (session id) of the player whose turn it is
    * `status`         – `:playing` for now; reserved for future
                         `:won` / `:lost` transitions.
    * `order`          – comma-joined, sorted list of the two user_ids.
                         The first entry is the starting turn.

  The order list is computed at game start and stored so we can
  alternate between the two players without a separate "previous
  turn" bookkeeping field.
  """

  alias MinesweeperBackend.{Base85, Redix}

  @game_prefix "room:"
  @game_suffix ":game"

  def board_size, do: Application.get_env(:minesweeper_backend, :game_board_size, 8)
  def mine_count, do: Application.get_env(:minesweeper_backend, :game_mine_count, 10)

  @doc """
  Starts a new game in `room_id`. `members` is the list of session
  ids currently in the room; the first one (callers should sort for
  determinism) becomes the starting player.

  Returns `{:ok, %{board_size: _, mine_count: _, board: <base85>}}`
  or `{:error, reason}`. A game that is currently `:playing` cannot
  be restarted; call `clear/1` (or finish the round) first.
  """
  def start_game(room_id, members) when is_list(members) do
    cond do
      length(members) != 2 ->
        {:error, :not_enough_players}

      status(room_id) == :playing ->
        {:error, :already_playing}

      true ->
        size = board_size()
        mines = mine_count()
        board = generate_board(size, mines)
        encoded = encode_board(board)
        [first, second | _] = Enum.sort(members)

        :ok =
          Redix.command([
            "HSET",
            game_key(room_id),
            "board_size",
            Integer.to_string(size),
            "mine_count",
            Integer.to_string(mines),
            "board",
            encoded,
            "current_turn",
            first,
            "status",
            "playing",
            "winner",
            "",
            "order",
            Enum.join([first, second], ",")
          ])

        {:ok,
         %{
           board_size: size,
           mine_count: mines,
           board: encoded,
           current_turn: first,
           order: [first, second]
         }}
    end
  end

  @doc "Returns the game status (`:playing` / `:cleared` / `nil`)."
  def status(room_id) do
    case Redix.command(["HGET", game_key(room_id), "status"]) do
      {:ok, nil} -> nil
      {:ok, "playing"} -> :playing
      {:ok, "cleared"} -> :cleared
      _ -> nil
    end
  end

  @doc """
  Records `user_id` as the winner of the current game and marks the
  game as `:cleared`. Subsequent `take_turn/2` calls return
  `{:error, :game_over}` until a new game is started.

  Returns `{:ok, user_id}` on success, `{:error, reason}` otherwise.
  """
  def report_clear(room_id, user_id) do
    cond do
      status(room_id) != :playing ->
        {:error, :no_active_game}

      user_id not in (order(room_id) || []) ->
        {:error, :not_a_player}

      true ->
        :ok =
          Redix.command([
            "HSET",
            game_key(room_id),
            "status",
            "cleared",
            "winner",
            user_id
          ])

        {:ok, user_id}
    end
  end

  @doc "Returns the winner of the most recently cleared game, or `nil`."
  def winner(room_id) do
    case Redix.command(["HGET", game_key(room_id), "winner"]) do
      {:ok, nil} -> nil
      {:ok, ""} -> nil
      {:ok, user_id} -> user_id
      _ -> nil
    end
  end

  @doc "Returns the current turn's user_id, or `nil` if no game is running."
  def current_turn(room_id) do
    case Redix.command(["HGET", game_key(room_id), "current_turn"]) do
      {:ok, nil} -> nil
      {:ok, user_id} -> user_id
      _ -> nil
    end
  end

  @doc "Returns the stored `order` list, or `nil` if no game is running."
  def order(room_id) do
    case Redix.command(["HGET", game_key(room_id), "order"]) do
      {:ok, nil} -> nil
      {:ok, list} -> String.split(list, ",", trim: true)
      _ -> nil
    end
  end

  @doc "Returns the stored board payload (size, mine_count, base85). Nil if no game."
  def board_payload(room_id) do
    case Redix.command(["HMGET", game_key(room_id), "board_size", "mine_count", "board"]) do
      {:ok, [size, mines, board]}
      when is_binary(size) and is_binary(mines) and is_binary(board) ->
        {:ok,
         %{
           board_size: String.to_integer(size),
           mine_count: String.to_integer(mines),
           board: board
         }}

      _ ->
        nil
    end
  end

  @doc """
  Attempts to process a `boardClick` from `user_id`.

  Returns:

    * `{:ok, :next_turn, next_user_id}` – the click was valid; broadcast
      the click, advance, and the next player is `next_user_id`.
    * `{:error, :not_your_turn}` – the click came from the wrong player.
    * `{:error, :no_game}` – no game is currently running.
    * `{:error, :game_over}` – the game is in a terminal state.
  """
  def take_turn(room_id, user_id) do
    cond do
      is_nil(order(room_id)) ->
        {:error, :no_game}

      status(room_id) == :cleared ->
        {:error, :game_over}

      true ->
        case current_turn(room_id) do
          nil ->
            {:error, :no_game}

          current ->
            case ensure_turn(current, user_id) do
              :ok ->
                next = next_player(order(room_id), current)
                :ok = Redix.command(["HSET", game_key(room_id), "current_turn", next])
                {:ok, :next_turn, next}

              {:error, :not_your_turn} = err ->
                err
            end
        end
    end
  end

  @doc "Clears the game state for `room_id` (used when leaving or restarting)."
  def clear(room_id) do
    case Redix.command(["DEL", game_key(room_id)]) do
      {:ok, _} -> :ok
      _ -> :ok
    end
  end

  # ---------------------------------------------------------------------------
  # board generation
  # ---------------------------------------------------------------------------

  defp generate_board(size, mine_count) do
    total = size * size
    mine_positions = mine_positions(total, mine_count)

    for i <- 0..(total - 1), into: <<>> do
      <<if(i in mine_positions, do: 1, else: 0)>>
    end
  end

  defp mine_positions(total, count) do
    Enum.shuffle(0..(total - 1)) |> Enum.take(count) |> MapSet.new()
  end

  # ---------------------------------------------------------------------------
  # base85 codec
  # ---------------------------------------------------------------------------

  @doc """
  Encodes a bitstring to RFC 1924 Base85. The bitstring is padded
  with zero bits to a multiple of 4 bytes so `Base85.encode/1` can
  chunk it cleanly.
  """
  def encode_board(bits) when is_binary(bits) do
    pad = (-byte_size(bits)) |> rem(4) |> Kernel.+(4) |> rem(4)
    padded = bits <> :binary.copy(<<0>>, pad)
    Base85.encode(padded)
  end

  @doc """
  Decodes an RFC 1924 Base85 string back to its original bitstring.
  Returns `{:ok, bits}` or `{:error, reason}`.
  """
  def decode_board(encoded) when is_binary(encoded) do
    Base85.decode(encoded)
  end

  # ---------------------------------------------------------------------------
  # turn helpers
  # ---------------------------------------------------------------------------

  defp ensure_turn(current, user_id) when current == user_id, do: :ok
  defp ensure_turn(_current, _user_id), do: {:error, :not_your_turn}

  defp next_player([a, b], current) when current == a, do: b
  defp next_player([a, b], current) when current == b, do: a
  defp next_player(order, _current), do: hd(order)

  defp game_key(room_id), do: @game_prefix <> room_id <> @game_suffix
end
