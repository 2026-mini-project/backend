defmodule MinesweeperBackendWeb.API.CreateSessionRequest do
  @moduledoc """
  OpenAPI schema for `POST /session` request body.
  """

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "CreateSessionRequest",
    type: :object,
    properties: %{
      name: %OpenApiSpex.Schema{type: :string, description: "Display name (1-32 chars)."}
    },
    required: [:name],
    example: %{name: "player1"}
  })
end
