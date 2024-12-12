defmodule ExamplePhoenix.Repo.Migrations.AddUserAvatarToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :user_avatar, :string
    end
  end
end
