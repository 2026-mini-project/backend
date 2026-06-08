defmodule MinesweeperBackend.Rooms.Room do
  @moduledoc """
  A multiplayer game room owned by a user.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MinesweeperBackend.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "rooms" do
    field :name, :string
    field :max_players, :integer, default: 2

    belongs_to :owner, User, foreign_key: :owner_id

    timestamps(type: :utc_datetime)
  end

  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :owner_id, :max_players])
    |> validate_required([:name, :owner_id, :max_players])
    |> validate_length(:name, min: 1, max: 64)
    |> validate_number(:max_players, greater_than: 0, less_than_or_equal_to: 8)
    |> assoc_constraint(:owner)
  end
end
