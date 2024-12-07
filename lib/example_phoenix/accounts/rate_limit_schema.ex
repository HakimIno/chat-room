defmodule ExamplePhoenix.Accounts.RateLimitSchema do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rate_limits" do
    field :ip_address, :string
    field :blocked_until, :naive_datetime
    field :spam_count, :integer, default: 0
    field :last_message_time, :naive_datetime

    timestamps()
  end

  def changeset(rate_limit, attrs) do
    rate_limit
    |> cast(attrs, [:ip_address, :blocked_until, :spam_count, :last_message_time])
    |> validate_required([:ip_address])
  end
end
