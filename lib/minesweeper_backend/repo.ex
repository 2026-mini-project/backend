defmodule MinesweeperBackend.Repo do
  use Ecto.Repo,
    otp_app: :minesweeper_backend,
    adapter: Ecto.Adapters.Postgres
end
