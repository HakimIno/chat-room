defmodule ExamplePhoenix.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products) do
      add :name, :string
      add :price, :decimal
      add :description, :string

      timestamps(type: :utc_datetime)
    end
  end
end
