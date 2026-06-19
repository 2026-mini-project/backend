defmodule MinesweeperBackend.Accounts do
  @moduledoc """
  Session / user management.

  A "session" in this app is literally a `users` row whose id is used
  as the bearer token in the `Authorization` header. Postgres is the
  source of truth; Redis caches `session:<sid> -> user_id` with a TTL
  so the hot auth path is a single in-memory lookup.
  """

  alias MinesweeperBackend.{MemoryStore, Repo, Redix}
  alias MinesweeperBackend.Accounts.User
  import Ecto.Query, only: [from: 2]

  @session_prefix "session:"

  @doc """
  Creates a new user and writes the session entry to Redis.
  Returns `{:ok, %User{}}`, `{:error, %Ecto.Changeset{}}`, or
  `{:error, :service_unavailable}` when the database cannot be reached.
  """
  def create_session(attrs) do
    with {:ok, name} <- validate_nickname(attrs),
         false <- nickname_taken?(name) do
      attrs = %{"name" => name}

      if memory_storage?(),
        do: MemoryStore.create_user(attrs),
        else: create_session_with_repo(attrs)
    else
      true -> {:error, "이미 사용 중인 닉네임입니다"}
      error -> error
    end
  end

  defp create_session_with_repo(attrs) do
    case insert_user(attrs) do
      {:ok, user} ->
        :ok = put_session_cache(user.id)
        {:ok, user}

      error ->
        error
    end
  end

  defp insert_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  rescue
    DBConnection.ConnectionError -> {:error, :service_unavailable}
  end

  @doc """
  Extends the lifetime of an existing session by re-setting the Redis
  cache key with the configured TTL. Returns `:ok` on success or
  `{:error, :unauthorized}` if no matching session/user exists.
  """
  def refresh_session(nil), do: {:error, :unauthorized}
  def refresh_session(""), do: {:error, :unauthorized}

  def refresh_session(session_id) when is_binary(session_id) do
    if memory_storage?() do
      refresh_memory_session(session_id)
    else
      refresh_repo_session(session_id)
    end
  end

  defp refresh_memory_session(session_id) do
    with :ok <- validate_uuid(session_id) do
      MemoryStore.refresh_session(session_id)
    else
      _ -> {:error, :unauthorized}
    end
  end

  defp refresh_repo_session(session_id) do
    with :ok <- validate_uuid(session_id),
         {:ok, user_id} <- lookup_session(session_id),
         :ok <- put_session_cache(user_id) do
      :ok
    else
      _ -> {:error, :unauthorized}
    end
  end

  @doc """
  Deletes an existing session.

  In this application the user row is the session's source of truth, so
  logout removes both the Redis cache entry and the user record.
  """
  def delete_session(nil), do: {:error, :unauthorized}
  def delete_session(""), do: {:error, :unauthorized}

  def delete_session(session_id) when is_binary(session_id) do
    if memory_storage?() do
      delete_memory_session(session_id)
    else
      delete_repo_session(session_id)
    end
  end

  defp delete_memory_session(session_id) do
    with :ok <- validate_uuid(session_id) do
      MemoryStore.delete_session(session_id)
    else
      _ -> {:error, :unauthorized}
    end
  end

  defp delete_repo_session(session_id) do
    with :ok <- validate_uuid(session_id),
         %User{} = user <- Repo.get(User, session_id),
         {:ok, _user} <- Repo.delete(user) do
      delete_session_cache(session_id)
      :ok
    else
      _ -> {:error, :unauthorized}
    end
  rescue
    DBConnection.ConnectionError -> {:error, :service_unavailable}
  end

  @doc """
  Looks up the user behind a session id.

  Tries Redis first; if missing, falls back to Postgres and rehydrates
  the cache so subsequent calls stay hot.
  """
  def fetch_user_by_session(nil), do: {:error, :unauthorized}
  def fetch_user_by_session(""), do: {:error, :unauthorized}

  def fetch_user_by_session(session_id) when is_binary(session_id) do
    if memory_storage?() do
      fetch_memory_user_by_session(session_id)
    else
      fetch_repo_user_by_session(session_id)
    end
  end

  defp fetch_memory_user_by_session(session_id) do
    with :ok <- validate_uuid(session_id),
         {:ok, user} <- MemoryStore.fetch_user(session_id) do
      {:ok, user}
    else
      _ -> {:error, :unauthorized}
    end
  end

  defp fetch_repo_user_by_session(session_id) do
    with :ok <- validate_uuid(session_id),
         {:ok, user_id} <- lookup_session(session_id),
         %User{} = user <- Repo.get(User, user_id) do
      {:ok, user}
    else
      _ -> {:error, :unauthorized}
    end
  end

  defp lookup_session(session_id) do
    case Redix.command(["GET", @session_prefix <> session_id]) do
      {:ok, nil} ->
        case Repo.get(User, session_id) do
          nil ->
            {:error, :unauthorized}

          %User{id: id} ->
            _ = put_session_cache(id)
            {:ok, id}
        end

      {:ok, user_id} ->
        {:ok, user_id}

      {:error, _} = err ->
        err
    end
  end

  defp put_session_cache(user_id) do
    ttl = Application.get_env(:minesweeper_backend, :session_ttl_seconds, 3_600)

    case Redix.command(["SET", @session_prefix <> user_id, user_id, "EX", Integer.to_string(ttl)]) do
      {:ok, _} -> :ok
      _ -> :ok
    end
  end

  defp delete_session_cache(session_id) do
    case Redix.command(["DEL", @session_prefix <> session_id]) do
      {:ok, _} -> :ok
      _ -> :ok
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

  defp nickname_taken?(name) do
    if memory_storage?() do
      MemoryStore.nickname_taken?(name)
    else
      Repo.exists?(from(user in User, where: user.name == ^name))
    end
  rescue
    DBConnection.ConnectionError -> false
  end

  defp memory_storage? do
    Application.get_env(:minesweeper_backend, :storage_driver) == "memory"
  end
end
