defmodule ExamplePhoenix.Repo.Migrations.AddImageUrlToRooms do
  use Ecto.Migration

  def change do
    alter table(:rooms) do
      add :image_url, :string
      modify :last_active_users, {:array, :map}, from: {:array, :string}, default: []
    end
  end
end
