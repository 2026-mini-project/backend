defmodule MinesweeperBackendWeb.Router do
  use MinesweeperBackendWeb, :router

  alias MinesweeperBackendWeb.Plugs.Authenticate

  pipeline :api do
    plug(:accepts, ["json"])
    plug(OpenApiSpex.Plug.PutApiSpec, module: MinesweeperBackendWeb.ApiSpec)
  end

  pipeline :authenticated do
    plug(Authenticate)
  end

  scope "/", MinesweeperBackendWeb do
    pipe_through(:api)

    get("/", StatusController, :index)
    post("/session", SessionController, :create)
  end

  scope "/", MinesweeperBackendWeb do
    pipe_through([:api, :authenticated])

    get("/session", SessionController, :show)
    delete("/session", SessionController, :delete)
    post("/session/refresh", SessionController, :refresh)
    get("/rooms", RoomController, :index)
    get("/rooms/:id", RoomController, :show)
    post("/rooms", RoomController, :create)
  end

  scope "/" do
    pipe_through(:api)

    get("/api/swagger.json", OpenApiSpex.Plug.RenderSpec, [])
  end

  scope "/docs" do
    pipe_through(:api)

    get("/*path", OpenApiSpex.Plug.SwaggerUI, path: "/api/swagger.json")
  end
end
