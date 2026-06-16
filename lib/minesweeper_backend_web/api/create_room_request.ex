defmodule MinesweeperBackendWeb.API.CreateRoomRequest do
  @moduledoc """
  OpenAPI schema for `POST /rooms` request body.
  """

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "CreateRoomRequest",
    type: :object,
    properties: %{
      name: %OpenApiSpex.Schema{type: :string, description: "Room display name (1-64 chars)."}
    },
    required: [:name],
    example: %{name: "lobby"}
  })
end
