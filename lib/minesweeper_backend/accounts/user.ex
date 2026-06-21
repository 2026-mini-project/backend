defmodule MinesweeperBackend.Accounts.User do
  @moduledoc """
  Persistent record for a player.

  `id` (a UUID) is also the SessionId returned to the client.
  We do not store credentials – the only identifier the client ever
  sees is this UUID.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder, only: [:id, :name]}

  schema "users" do
    field(:name, :string)
    field(:expires_at, :utc_datetime_usec)
    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :expires_at])
    |> validate_required([:name, :expires_at])
    |> validate_length(:name, min: 5, max: 32)
    |> unique_constraint(:name)
  end

  @doc """
  Changeset used to extend the lifetime of an existing session. Only
  the `expires_at` field is mutable; the rest is part of the session
  identity.
  """
  def refresh_changeset(user, attrs) do
    user
    |> cast(attrs, [:expires_at])
    |> validate_required([:expires_at])
  end
end
