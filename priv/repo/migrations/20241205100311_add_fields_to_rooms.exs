defmodule ExamplePhoenix.Repo.Migrations.AddFieldsToRooms do
  use Ecto.Migration

  def change do
    alter table(:rooms) do
      add :is_private, :boolean, default: false
      add :password, :string
      add :creator_id, :string
      add :last_active_users, {:array, :map}, default: []
    end
  end
end
