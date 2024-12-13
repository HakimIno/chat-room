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
    field :dm_room_id, :string
    field :participants, {:array, :string}, default: []
    field :last_active_users, {:array, :map}, virtual: true, default: []

    timestamps()
  end

  @doc false
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :category, :is_private, :password, :theme, :creator_id, :dm_room_id, :participants])
    |> validate_required([:name, :category, :theme])
    |> validate_inclusion(:theme, ["modern", "minimal", "nature"])
    |> validate_password_if_private()
    |> unique_constraint(:dm_room_id)
  end

  defp validate_dm_room(changeset) do
    if get_field(changeset, :category) == "dm" do
      changeset
      |> validate_required([:dm_room_id, :participants])
      |> validate_length(:participants, is: 2, message: "DM room must have exactly 2 participants")
    else
      changeset
    end
  end

  defp validate_password_if_private(changeset) do
    is_private = get_field(changeset, :is_private)
    is_dm = get_field(changeset, :category) == "dm"

    cond do
      is_dm ->
        changeset
      is_private ->
        validate_required(changeset, [:password])
      true ->
        changeset
    end
  end
end
