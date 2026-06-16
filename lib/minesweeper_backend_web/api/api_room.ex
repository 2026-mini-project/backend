defmodule MinesweeperBackendWeb.API.APIRoom do
  @moduledoc """
  OpenAPI schema for `APIRoom`:

      {
        "id": string,
        "name": string,
        "owner": string,  // SessionId
        "full": boolean
      }
  """

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "APIRoom",
    description: "A multiplayer game room owned by a user.",
    type: :object,
    properties: %{
      id: %OpenApiSpex.Schema{type: :string, format: :uuid, description: "Room id."},
      name: %OpenApiSpex.Schema{type: :string, description: "Display name."},
      owner: %OpenApiSpex.Schema{
        type: :string,
        format: :uuid,
        description: "Session id of the room owner."
      },
      full: %OpenApiSpex.Schema{
        type: :boolean,
        description: "Whether the room has reached `max_players`."
      }
    },
    required: [:id, :name, :owner, :full],
    example: %{
      id: "00000000-0000-0000-0000-000000000000",
      name: "my-room",
      owner: "00000000-0000-0000-0000-000000000001",
      full: false
    }
  })
end
