defmodule ExamplePhoenix.Repo.Migrations.AddMediaToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :media_url, :string
      add :media_type, :string
      add :content_type, :string
    end
  end
end
