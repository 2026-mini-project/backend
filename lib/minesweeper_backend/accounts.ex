defmodule MinesweeperBackend.Accounts do
  @moduledoc """
  Session / user management backed by in-memory storage.

  A session is a user record whose id is used as the bearer token in the
  `Authorization` header.
  """

  alias MinesweeperBackend.MemoryStore

  def create_session(attrs) do
    with {:ok, name} <- validate_nickname(attrs) do
      MemoryStore.create_user(%{"name" => name})
    end
  end

  def refresh_session(nil), do: {:error, :unauthorized}
  def refresh_session(""), do: {:error, :unauthorized}

  def refresh_session(session_id) when is_binary(session_id) do
    with :ok <- validate_uuid(session_id) do
      MemoryStore.refresh_session(session_id)
    else
      _ -> {:error, :unauthorized}
    end
  end

  def delete_session(nil), do: {:error, :unauthorized}
  def delete_session(""), do: {:error, :unauthorized}

  def delete_session(session_id) when is_binary(session_id) do
    with :ok <- validate_uuid(session_id) do
      MemoryStore.delete_session(session_id)
    else
      _ -> {:error, :unauthorized}
    end
  end

  def fetch_user_by_session(nil), do: {:error, :unauthorized}
  def fetch_user_by_session(""), do: {:error, :unauthorized}

  def fetch_user_by_session(session_id) when is_binary(session_id) do
    with :ok <- validate_uuid(session_id),
         {:ok, user} <- MemoryStore.fetch_user(session_id) do
      {:ok, user}
    else
      _ -> {:error, :unauthorized}
    end
  end

  defp validate_uuid(value) do
    case Ecto.UUID.cast(value) do
      {:ok, _} -> :ok
      :error -> {:error, :unauthorized}
    end
  end

  defp validate_nickname(%{"name" => name}) when is_binary(name),
    do: validate_nickname_value(name)

  defp validate_nickname(%{name: name}) when is_binary(name), do: validate_nickname_value(name)
  defp validate_nickname(_), do: {:error, "닉네임을 입력해야 합니다"}

  defp validate_nickname_value(name) do
    name = String.trim(name)

    cond do
      name == "" -> {:error, "닉네임을 입력해야 합니다"}
      String.length(name) <= 4 -> {:error, "닉네임은 5자 이상이어야 합니다"}
      true -> {:ok, name}
    end
  end
end
