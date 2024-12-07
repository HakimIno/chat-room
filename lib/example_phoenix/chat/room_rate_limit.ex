defmodule ExamplePhoenix.Chat.RoomRateLimit do
  use Ecto.Schema
  import Ecto.Changeset

  schema "room_rate_limits" do
    field :user_id, :string
    field :attempt_count, :integer
    field :last_attempt_at, :naive_datetime

    timestamps()
  end

  def changeset(room_rate_limit, attrs) do
    room_rate_limit
    |> cast(attrs, [:user_id, :attempt_count, :last_attempt_at])
    |> validate_required([:user_id, :attempt_count, :last_attempt_at])
  end
end
