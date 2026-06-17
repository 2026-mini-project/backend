defmodule MinesweeperBackendWeb.API.CreateRoomRequest do
  @moduledoc """
  OpenAPI schema for `POST /rooms` request body.
  """

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "CreateRoomRequest",
    type: :object,
    properties: %{
      name: %OpenApiSpex.Schema{type: :string, description: "Room display name (1-64 chars)."},
      private: %OpenApiSpex.Schema{
        type: :boolean,
        description: "Hide the room from `GET /rooms`. Defaults to false."
      }
    },
    required: [:name],
    example: %{name: "lobby", private: false}
  })
end
