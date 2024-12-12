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
    |> validate_required([:content, :user_name, :user_avatar, :room_id])
    |> validate_at_least_one_present([:content, :media_url])
    |> foreign_key_constraint(:room_id)
  end

  defp validate_at_least_one_present(changeset, fields) do
    if Enum.any?(fields, &present?(changeset, &1)) do
      changeset
    else
      add_error(changeset, hd(fields), "at least one of #{inspect(fields)} must be present")
    end
  end

  defp present?(changeset, field) do
    value = get_field(changeset, field)
    value && value != ""
  end
end
