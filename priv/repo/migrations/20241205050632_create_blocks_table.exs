defmodule ExamplePhoenix.Repo.Migrations.CreateBlocksTable do
  use Ecto.Migration

  def change do
    create table(:blocks) do
      add :ip_address, :string, null: false
      add :expires_at, :naive_datetime, null: false

      timestamps()
    end

    # เพิ่ม index เพื่อเพิ่มประสิทธิภาพการค้นหา
    create index(:blocks, [:ip_address])
    create index(:blocks, [:expires_at])
  end
end
