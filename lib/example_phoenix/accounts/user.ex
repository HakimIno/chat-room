defmodule ExamplePhoenix.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias ExamplePhoenix.Repo

  schema "users" do
    field :name, :string
    field :blocked_until, :naive_datetime
    field :last_message_time, :naive_datetime
    field :message_count, :integer, default: 0

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :blocked_until, :last_message_time, :message_count])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 30)
    |> unique_constraint(:name)
  end

  def create_user(name) do
    %__MODULE__{}
    |> changeset(%{name: name})
    |> Repo.insert()
  end
end
