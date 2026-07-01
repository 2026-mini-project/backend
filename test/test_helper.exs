ExUnit.start()

Application.put_env(:minesweeper_backend, :room_empty_ttl_seconds, 0)

{:ok, _} = Application.ensure_all_started(:minesweeper_backend)
