defmodule ExamplePhoenix.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias ExamplePhoenix.Repo
  alias ExamplePhoenix.Accounts.User

  schema "users" do
    field :name, :string
    field :blocked_until, :naive_datetime
    field :last_message_time, :naive_datetime
    field :message_count, :integer, default: 0
    field :avatar, :string

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :blocked_until, :last_message_time, :message_count, :avatar])
    |> validate_required([:name, :avatar])
    |> validate_length(:name, min: 2, max: 30)
    |> unique_constraint(:name)
  end

  def create_user(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  def get_user_by_name(name) do
    Repo.get_by(__MODULE__, name: name)
  end

  def update_user(%__MODULE__{} = user, attrs) do
    user
    |> changeset(attrs)
    |> Repo.update()
  end
end
