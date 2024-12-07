defmodule ExamplePhoenix.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :content, :string
    field :user_name, :string
    field :user_ip, :string
    belongs_to :room, ExamplePhoenix.Chat.Room

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :user_name, :room_id, :user_ip])
    |> validate_required([:content, :user_name, :room_id])
  end
end
