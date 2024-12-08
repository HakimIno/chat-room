defmodule ExamplePhoenix.Repo.Migrations.FixEmptyMediaUrls do
  use Ecto.Migration

  def up do
    execute """
    UPDATE messages
    SET media_url = NULL
    WHERE media_url IS NOT NULL AND (
      media_url::text SIMILAR TO '\\[\\]' OR
      media_url = ''
    );
    """
  end

  def down do
    :ok
  end
end
