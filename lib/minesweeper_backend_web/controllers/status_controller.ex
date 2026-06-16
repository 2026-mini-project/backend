defmodule MinesweeperBackendWeb.StatusController do
  @moduledoc """
  Liveness probe.
  """

  use MinesweeperBackendWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias MinesweeperBackendWeb.API.StatusResponse

  operation :index,
    tags: ["status"],
    summary: "Liveness check",
    operation_id: "getStatus",
    responses: [
      ok: %OpenApiSpex.Response{
        description: "Server is running",
        content: %{"application/json" => %OpenApiSpex.MediaType{schema: StatusResponse}}
      }
    ]

  def index(conn, _params) do
    json(conn, %{running: true})
  end
end
