defmodule ExamplePhoenix.Repo.Migrations.CreateUsersTable do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :name, :string, null: false
      add :blocked_until, :naive_datetime
      add :last_message_time, :naive_datetime
      add :message_count, :integer, default: 0

      timestamps()
    end

    create unique_index(:users, [:name])
  end
end
