defmodule MinesweeperBackendWeb.ApiSpec do
  @moduledoc """
  OpenAPI 3.0 specification for the HTTP surface of the backend.

  Served at `GET /api/swagger.json`. The interactive UI is at `GET /docs`.
  WebSocket events are documented separately in the README.
  """

  alias OpenApiSpex.{Components, Info, OpenApi, Paths, Server}

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [
        %Server{url: "http://localhost:4000", description: "Local dev"}
      ],
      info: %Info{
        title: "Minesweeper Backend API",
        version: "0.1.0",
        description: """
        HTTP API for the 2026 mini-project minesweeper backend.

        WebSocket events (the actual game flow) are documented in the
        repository README; this OpenAPI document covers REST only.
        """
      },
      components: %Components{
        securitySchemes: %{
          "SessionId" => %OpenApiSpex.SecurityScheme{
            type: :apiKey,
            in: :header,
            name: "Authorization",
            description: "Raw session id (UUID). May be prefixed with `Bearer `."
          }
        }
      },
      paths: Paths.from_router(MinesweeperBackendWeb.Router)
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
