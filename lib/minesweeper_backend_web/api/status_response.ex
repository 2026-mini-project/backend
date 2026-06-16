defmodule MinesweeperBackendWeb.API.StatusResponse do
  @moduledoc """
  OpenAPI schema for `GET /`:

      { "running": boolean }
  """

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "StatusResponse",
    type: :object,
    properties: %{
      running: %OpenApiSpex.Schema{type: :boolean, description: "True when the server is up."}
    },
    required: [:running],
    example: %{running: true}
  })
end
