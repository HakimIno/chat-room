defmodule ExamplePhoenix.Accounts.Block do
  use Ecto.Schema
  import Ecto.Changeset

  schema "blocks" do
    field :ip_address, :string
    field :expires_at, :naive_datetime

    timestamps()
  end

  def changeset(block, attrs) do
    block
    |> cast(attrs, [:ip_address, :expires_at])
    |> validate_required([:ip_address, :expires_at])
  end
end
