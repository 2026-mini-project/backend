defmodule MinesweeperBackendWeb.Router do
  use MinesweeperBackendWeb, :router

  alias MinesweeperBackendWeb.Plugs.Authenticate

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated do
    plug Authenticate
  end

  scope "/", MinesweeperBackendWeb do
    pipe_through :api

    get "/", StatusController, :index
    post "/session", SessionController, :create
  end

  scope "/", MinesweeperBackendWeb do
    pipe_through [:api, :authenticated]

    get "/session", SessionController, :show
    post "/session/refresh", SessionController, :refresh
    get "/rooms/:id", RoomController, :show
    post "/rooms", RoomController, :create
  end
end
