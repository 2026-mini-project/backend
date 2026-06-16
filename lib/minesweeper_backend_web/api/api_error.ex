defmodule MinesweeperBackendWeb.API.APIError do
  @moduledoc """
  OpenAPI schema for `APIError`:

      { "message": string }
  """

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "APIError",
    description: "Standard error envelope returned by every failing request.",
    type: :object,
    properties: %{
      message: %OpenApiSpex.Schema{type: :string, description: "Human-readable error."}
    },
    required: [:message],
    example: %{message: "unauthorized"}
  })
end
