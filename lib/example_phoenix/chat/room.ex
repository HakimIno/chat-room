defmodule ExamplePhoenix.Chat.Room do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :integer, autogenerate: false}
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
    attrs =
      if is_nil(attrs["id"]) do
        Map.put(attrs, "id", generate_room_id())
      else
        attrs
      end

    room
    |> cast(attrs, [
      :id,
      :name,
      :category,
      :is_private,
      :password,
      :theme,
      :creator_id,
      :dm_room_id,
      :participants
    ])
    |> validate_required([:id, :name, :category, :theme])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_inclusion(:theme, ["modern", "minimal", "nature"])
    |> validate_password_if_private()
    |> unique_constraint(:dm_room_id)
  end

  defp validate_dm_room(changeset) do
    if get_field(changeset, :category) == "dm" do
      changeset
      |> validate_required([:dm_room_id, :participants])
      |> validate_length(:participants,
        is: 2,
        message: "DM room must have exactly 2 participants"
      )
    else
      changeset
    end
  end

  defp generate_room_id do
    min = String.to_integer("100000000000")
    max = String.to_integer("999999999999")
    room_id = Enum.random(min..max)

    case ExamplePhoenix.Repo.get(__MODULE__, room_id) do
      nil -> room_id
      _ -> generate_room_id()
    end
  end

  defp validate_password_if_private(changeset) do
    is_private = get_field(changeset, :is_private)
    password = get_field(changeset, :password)

    cond do
      is_private && (is_nil(password) || password == "") ->
        add_error(changeset, :password, "ห้องส่วนตัวต้องมีรหัสผ่าน")

      is_private && !is_nil(password) ->
        validate_length(changeset, :password,
          min: 4,
          message: "รหัสผ่านต้องมีความยาวอย่างน้อย 4 ตัวอักษร"
        )

      true ->
        changeset
    end
  end

  def verify_room_password(room, password) do
    cond do
      !room.is_private ->
        {:ok, room}

      room.is_private && room.password == password ->
        {:ok, room}

      true ->
        {:error, :invalid_password}
    end
  end
end
