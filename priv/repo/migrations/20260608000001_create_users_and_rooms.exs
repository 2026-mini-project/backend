defmodule MinesweeperBackend.Repo.Migrations.CreateUsersAndRooms do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS \"pgcrypto\"", "DROP EXTENSION IF EXISTS \"pgcrypto\"")

    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :string, size: 32, null: false
      timestamps(type: :utc_datetime)
    end

    create table(:rooms, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :string, size: 64, null: false

      add :owner_id,
          references(:users, type: :binary_id, on_delete: :delete_all),
          null: false

      add :max_players, :integer, null: false, default: 2
      timestamps(type: :utc_datetime)
    end

    create index(:rooms, [:owner_id])
    create constraint(:rooms, :rooms_max_players_positive, check: "max_players > 0")
  end
end
