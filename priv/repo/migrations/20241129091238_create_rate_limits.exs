defmodule ExamplePhoenix.Repo.Migrations.CreateRateLimits do
  use Ecto.Migration

  def change do
    create table(:rate_limits) do
      add :ip_address, :string, null: false
      add :blocked_until, :naive_datetime
      add :spam_count, :integer, default: 0
      add :last_message_time, :naive_datetime

      timestamps()
    end

    create unique_index(:rate_limits, [:ip_address])
  end
end
