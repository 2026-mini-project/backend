defmodule MinesweeperBackendWeb.SocketAuth do
  @moduledoc """
  Resolves a session id (UUID) presented by a WebSocket client during
  the `identify` handshake against the existing `session:<sid>` cache
  in Redis.

  Returns `{:ok, user_id}` when the session is known to the server,
  `{:error, :unauthorized}` otherwise. The lookup mirrors what the
  HTTP `Authenticate` plug does, but stays in this layer so the socket
  transport does not need to depend on the HTTP plug pipeline.
  """

  alias MinesweeperBackend.{Repo, Redix}
  alias MinesweeperBackend.Accounts.User

  @session_prefix "session:"

  @doc """
  Resolves `session_id` to a user id. Mirrors the behaviour of
  `MinesweeperBackend.Accounts.fetch_user_by_session/1`.
  """
  def resolve(session_id) when is_binary(session_id) do
    with :ok <- validate_uuid(session_id),
         {:ok, user_id} <- lookup_session(session_id) do
      {:ok, user_id}
    else
      _ -> {:error, :unauthorized}
    end
  end

  def resolve(_), do: {:error, :unauthorized}

  defp lookup_session(session_id) do
    case Redix.command(["GET", @session_prefix <> session_id]) do
      {:ok, nil} ->
        case Repo.get(User, session_id) do
          nil -> {:error, :unauthorized}
          %User{id: id} -> {:ok, id}
        end

      {:ok, user_id} when is_binary(user_id) ->
        {:ok, user_id}

      _ ->
        {:error, :unauthorized}
    end
  end

  defp validate_uuid(value) do
    case Ecto.UUID.cast(value) do
      {:ok, _} -> :ok
      :error -> {:error, :unauthorized}
    end
  end
end
