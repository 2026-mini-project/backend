defmodule MinesweeperBackendWeb.API.APIRoom do
  @moduledoc """
  OpenAPI schema for `APIRoom`:

      {
        "id": string,
        "name": string,
        "owner": string,  // SessionId
        "private": boolean,
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
        description: "Nickname of the room owner."
      },
      private: %OpenApiSpex.Schema{
        type: :boolean,
        description: "Whether the room is hidden from `GET /rooms`."
      },
      full: %OpenApiSpex.Schema{
        type: :boolean,
        description: "Whether the room has reached `max_players`."
      }
    },
    required: [:id, :name, :owner, :private, :full],
    example: %{
      id: "00000000-0000-0000-0000-000000000000",
      name: "my-room",
      owner: "player-one",
      private: false,
      full: false
    }
  })
end
