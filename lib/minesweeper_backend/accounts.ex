defmodule MinesweeperBackend.Accounts do
  @moduledoc """
  Session / user management.

  A "session" in this app is literally a `users` row whose id is used
  as the bearer token in the `Authorization` header. Postgres is the
  source of truth; Redis caches `session:<sid> -> user_id` with a TTL
  so the hot auth path is a single in-memory lookup.
  """

  alias MinesweeperBackend.{Repo, Redix}
  alias MinesweeperBackend.Accounts.User

  @session_prefix "session:"

  @doc """
  Creates a new user and writes the session entry to Redis.
  Returns `{:ok, %User{}}` or `{:error, %Ecto.Changeset{}}`.
  """
  def create_session(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, user} ->
        :ok = put_session_cache(user.id)
        {:ok, user}

      error ->
        error
    end
  end

  @doc """
  Looks up the user behind a session id.

  Tries Redis first; if missing, falls back to Postgres and rehydrates
  the cache so subsequent calls stay hot.
  """
  def fetch_user_by_session(nil), do: {:error, :unauthorized}
  def fetch_user_by_session(""), do: {:error, :unauthorized}

  def fetch_user_by_session(session_id) when is_binary(session_id) do
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
    ttl = Application.get_env(:minesweeper_backend, :session_ttl_seconds, 86_400)

    case Redix.command(["SET", @session_prefix <> user_id, user_id, "EX", Integer.to_string(ttl)]) do
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
end
