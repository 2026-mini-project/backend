defmodule MinesweeperBackend.Repo.Migrations.AddExpiresAtToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :expires_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() + interval '1 hour')")
    end

    create index(:users, [:expires_at])
  end
end
