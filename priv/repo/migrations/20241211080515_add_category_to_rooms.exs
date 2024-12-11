defmodule ExamplePhoenix.Repo.Migrations.AddCategoryToRooms do
  use Ecto.Migration

  def change do
    alter table(:rooms) do
      add :category, :string
    end
  end
end
