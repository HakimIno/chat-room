defmodule ExamplePhoenix.Repo.Migrations.AddDmFieldsToRooms do
  use Ecto.Migration

  def change do
    alter table(:rooms) do
      add :dm_room_id, :string
      add :participants, {:array, :string}, default: []
    end

    create unique_index(:rooms, [:dm_room_id])
  end
end
