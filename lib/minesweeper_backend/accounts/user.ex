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
    field :name, :string
    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 32)
  end
end
