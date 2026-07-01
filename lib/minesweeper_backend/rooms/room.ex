defmodule MinesweeperBackend.Rooms.Room do
  @moduledoc """
  In-memory multiplayer game room.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  embedded_schema do
    field :name, :string
    field :is_private, :boolean, default: false
    field :max_players, :integer, default: 2
    field :owner_id, :binary_id
    field :inserted_at, :utc_datetime
    field :updated_at, :utc_datetime
  end

  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :owner_id, :max_players, :is_private])
    |> validate_required([:name, :owner_id, :max_players])
    |> validate_length(:name, min: 1, max: 64)
    |> validate_number(:max_players, greater_than: 0, less_than_or_equal_to: 8)
  end
end
