defmodule ExamplePhoenix.Repo.Migrations.AddFaviconUrlToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :favicon_url, :string
    end
  end
end
