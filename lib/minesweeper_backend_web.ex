defmodule MinesweeperBackendWeb do
  @moduledoc """
  The entrypoint for defining the web interface (controllers, JSON
  views, plugs and routers).
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:json],
        layouts: []

      import Plug.Conn
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: MinesweeperBackendWeb.Endpoint,
        router: MinesweeperBackendWeb.Router,
        statics: MinesweeperBackendWeb.static_paths()
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
