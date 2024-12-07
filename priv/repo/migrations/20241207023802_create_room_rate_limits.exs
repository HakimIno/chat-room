defmodule ExamplePhoenix.Repo.Migrations.CreateRoomRateLimits do
  use Ecto.Migration

  def change do
    create table(:room_rate_limits) do
      add :user_id, :string, null: false
      add :attempt_count, :integer, default: 0
      add :last_attempt_at, :naive_datetime

      timestamps()
    end

    create unique_index(:room_rate_limits, [:user_id])
  end
end
