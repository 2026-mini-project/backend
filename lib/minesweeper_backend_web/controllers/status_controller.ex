defmodule MinesweeperBackendWeb.StatusController do
  use MinesweeperBackendWeb, :controller

  def index(conn, _params) do
    json(conn, %{running: true})
  end
end
