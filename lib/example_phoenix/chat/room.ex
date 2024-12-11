defmodule ExamplePhoenix.Chat.Room do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rooms" do
    field :name, :string
    field :is_private, :boolean, default: false
    field :password, :string
    field :creator_id, :string
    field :image_url, :string
    field :last_active_users, {:array, :map}, default: []
    field :category, :string
    timestamps()
  end

  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :is_private, :password, :creator_id, :image_url,:category])
    |> validate_required([:name, :creator_id, :category])
    |> validate_password_if_private()
  end

  defp validate_password_if_private(changeset) do
    if get_field(changeset, :is_private) do
      changeset
      |> validate_required([:password])
      |> validate_length(:password, min: 4)
    else
      changeset
    end
  end
end
