defmodule ExamplePhoenix.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :content, :string
    field :user_name, :string
    field :user_avatar, :string
    field :user_ip, :string
    field :media_url, :string
    field :media_type, :string
    field :content_type, :string
    field :title, :string
    belongs_to :room, ExamplePhoenix.Chat.Room

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a message.
  At least one of content or media_url must be present.
  """
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :user_name, :user_avatar, :room_id, :media_url, :media_type, :content_type, :title])
    |> validate_required([:user_name, :user_avatar, :room_id])
    |> validate_content_or_media()
    |> foreign_key_constraint(:room_id)
  end

  defp validate_content_or_media(changeset) do
    content = get_field(changeset, :content)
    media_url = get_field(changeset, :media_url)

    cond do
      is_binary(content) and byte_size(content) > 0 -> changeset
      is_binary(media_url) and byte_size(media_url) > 0 -> changeset
      true -> add_error(changeset, :content, "message or media is required")
    end
  end
end
