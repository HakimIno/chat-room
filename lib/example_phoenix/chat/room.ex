defmodule ExamplePhoenix.Chat.Room do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rooms" do
    field :name, :string
    field :category, :string
    field :is_private, :boolean, default: false
    field :password, :string
    field :theme, :string, default: "modern"
    field :creator_id, :string
    field :last_active_users, {:array, :map}, virtual: true, default: []

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :category, :is_private, :password, :theme, :creator_id])
    |> validate_required([:name, :category, :theme, :creator_id])
    |> validate_inclusion(:theme, ["modern", "minimal", "nature"])
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
