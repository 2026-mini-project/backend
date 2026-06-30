defmodule MinesweeperBackendWeb.SocketAuth do
  @moduledoc """
  Resolves a session id presented during the WebSocket `"identify"`
  handshake.

  Returns `{:ok, user_id}` when the session is known to the server,
  `{:error, :unauthorized}` otherwise.
  """

  alias MinesweeperBackend.Accounts

  @doc """
  Resolves `session_id` to a user id. Mirrors
  `MinesweeperBackend.Accounts.fetch_user_by_session/1`.
  """
  def resolve(session_id) when is_binary(session_id) do
    with :ok <- validate_uuid(session_id),
         {:ok, user} <- Accounts.fetch_user_by_session(session_id) do
      {:ok, user.id}
    else
      _ -> {:error, :unauthorized}
    end
  end

  def resolve(_), do: {:error, :unauthorized}

  defp validate_uuid(value) do
    case Ecto.UUID.cast(value) do
      {:ok, _} -> :ok
      :error -> {:error, :unauthorized}
    end
  end
end
