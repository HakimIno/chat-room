defmodule ExamplePhoenix.Repo.Migrations.CreateBlocks do
  use Ecto.Migration

  def change do
    create table(:blocks) do
      add :ip_address, :string
      add :expires_at, :naive_datetime

      timestamps()
    end

    create index(:blocks, [:ip_address])
  end
end
