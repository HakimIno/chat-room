defmodule ExamplePhoenix.Repo.Migrations.AddUserIpToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :user_ip, :string
    end
  end
end
