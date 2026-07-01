defmodule MinesweeperBackend.Accounts.User do
  @moduledoc """
  In-memory player record.

  `id` (a UUID) is also the SessionId returned to the client.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder, only: [:id, :name]}

  embedded_schema do
    field(:name, :string)
    field(:expires_at, :utc_datetime_usec)
    field(:inserted_at, :utc_datetime)
    field(:updated_at, :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :expires_at])
    |> validate_required([:name, :expires_at])
    |> validate_length(:name, min: 5, max: 32)
  end

  def refresh_changeset(user, attrs) do
    user
    |> cast(attrs, [:expires_at])
    |> validate_required([:expires_at])
  end
end
