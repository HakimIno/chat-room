defmodule ExamplePhoenix.Repo.Migrations.AddThemeToRooms do
  use Ecto.Migration

  def change do
    alter table(:rooms) do
      add :theme, :string, default: "modern", null: false
    end
  end
end
