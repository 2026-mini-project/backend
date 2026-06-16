defmodule MinesweeperBackendWeb.SessionController do
  use MinesweeperBackendWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias MinesweeperBackend.Accounts
  alias MinesweeperBackendWeb.API.{APIError, APIUser, CreateSessionRequest}
  alias MinesweeperBackendWeb.{FallbackController, SessionJSON}

  action_fallback FallbackController

  operation :show,
    tags: ["session"],
    summary: "Fetch the current user",
    operation_id: "getSession",
    security: [%{"SessionId" => []}],
    responses: [
      ok: %OpenApiSpex.Response{
        description: "Current session user",
        content: %{"application/json" => %OpenApiSpex.MediaType{schema: APIUser}}
      },
      unauthorized: %OpenApiSpex.Response{
        description: "No or invalid session",
        content: %{"application/json" => %OpenApiSpex.MediaType{schema: APIError}}
      }
    ]

  operation :create,
    tags: ["session"],
    summary: "Create a new session",
    operation_id: "createSession",
    request_body:
      {"Request body", "application/json", CreateSessionRequest, required: true},
    responses: [
      created: %OpenApiSpex.Response{
        description: "Session created",
        content: %{"application/json" => %OpenApiSpex.MediaType{schema: APIUser}}
      },
      bad_request: %OpenApiSpex.Response{
        description: "Validation failed",
        content: %{"application/json" => %OpenApiSpex.MediaType{schema: APIError}}
      }
    ]

  operation :refresh,
    tags: ["session"],
    summary: "Refresh the current session's TTL",
    operation_id: "refreshSession",
    security: [%{"SessionId" => []}],
    responses: [
      ok: %OpenApiSpex.Response{
        description: "Session refreshed",
        content: %{"application/json" => %OpenApiSpex.MediaType{schema: APIUser}}
      },
      unauthorized: %OpenApiSpex.Response{
        description: "No or invalid session",
        content: %{"application/json" => %OpenApiSpex.MediaType{schema: APIError}}
      }
    ]

  def show(conn, _params) do
    user = conn.assigns.current_user

    conn
    |> put_view(json: SessionJSON)
    |> render(:show, user: user)
  end

  def create(conn, params) do
    with {:ok, name} <- fetch_name(params),
         {:ok, user} <- Accounts.create_session(%{name: name}) do
      conn
      |> put_status(:created)
      |> put_view(json: SessionJSON)
      |> render(:show, user: user)
    end
  end

  def refresh(conn, _params) do
    user = conn.assigns.current_user

    with :ok <- Accounts.refresh_session(user.id) do
      conn
      |> put_view(json: SessionJSON)
      |> render(:show, user: user)
    end
  end

  defp fetch_name(%{"name" => name}) when is_binary(name) and name != "", do: {:ok, name}
  defp fetch_name(_), do: {:error, "name is required"}
end
