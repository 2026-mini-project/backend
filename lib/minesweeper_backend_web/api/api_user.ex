defmodule MinesweeperBackendWeb.API.APIUser do
  @moduledoc """
  OpenAPI schema for `APIUser`:

      { "id": string /* SessionId */, "name": string }
  """

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "APIUser",
    description: "A player. `id` is the session id and doubles as the user id.",
    type: :object,
    properties: %{
      id: %OpenApiSpex.Schema{
        type: :string,
        format: :uuid,
        description: "Session id; also the user id."
      },
      name: %OpenApiSpex.Schema{type: :string, description: "Display name."}
    },
    required: [:id, :name],
    example: %{
      id: "00000000-0000-0000-0000-000000000000",
      name: "player1"
    }
  })
end
