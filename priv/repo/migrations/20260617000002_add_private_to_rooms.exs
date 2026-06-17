defmodule MinesweeperBackend.Repo.Migrations.AddPrivateToRooms do
  use Ecto.Migration

  def change do
    alter table(:rooms) do
      add :is_private, :boolean, null: false, default: false
    end

    create index(:rooms, [:is_private])
  end
end
