# lib/example_phoenix/chat.ex
defmodule ExamplePhoenix.Chat do
  import Ecto.Query, warn: false
  alias ExamplePhoenix.Repo
  alias ExamplePhoenix.Chat.{Room, RoomRateLimit}
  alias ExamplePhoenix.Chat.{Room, Message}
  alias ExamplePhoenix.Chat.RoomRateLimit

  def list_rooms do
    Repo.all(Room)
  end

  def get_room(id) do
    case Repo.get(Room, id) do
      nil -> {:error, :not_found}
      room -> {:ok, room}
    end
  end

  def get_room!(id) do
    Repo.get!(Room, id)
  end

  def create_room(attrs \\ %{}) do
    %Room{}
    |> Room.changeset(attrs)
    |> Repo.insert()
  end

  def list_messages(room_id, limit \\ 100) do
    Message
    |> where([m], m.room_id == ^room_id)
    |> order_by([m], asc: m.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def create_message(attrs) do
    case %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert() do
      {:ok, message} = result ->
        # Broadcast ข้อความใหม่ไปยังทุกคนในห้อง
        Phoenix.PubSub.broadcast(
          ExamplePhoenix.PubSub,
          "room:#{message.room_id}",
          {:new_message, message}
        )
        result
      error -> error
    end
  end

  def search_rooms(query) when is_binary(query) do
    query = "%#{query}%"

    Room
    |> where([r], ilike(r.name, ^query))
    |> Repo.all()
  end

  def search_rooms(_), do: list_rooms()

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking room changes.
  """
  def change_room(%Room{} = room, attrs \\ %{}) do
    Room.changeset(room, attrs)
  end

  @doc """
  Updates a room.
  """
  def update_room(%Room{} = room, attrs) do
    room
    |> Room.changeset(attrs)
    |> Repo.update()
  end

  def update_last_active_users(room_id, user_name, avatar_url) do
    room = get_room!(room_id)
    current_users = room.last_active_users || []

    updated_users =
      ([%{name: user_name, avatar_url: avatar_url} | current_users])
      |> Enum.uniq_by(& &1.name)
      |> Enum.take(3)

    room
    |> Room.changeset(%{last_active_users: updated_users})
    |> Repo.update()
  end

  def list_rooms_with_presence do
    rooms = list_rooms()
    presence_data = ExamplePhoenix.Presence.list("room_presence")

    Enum.map(rooms, fn room ->
      room_presence = Map.get(presence_data, "room:#{room.id}", %{})
      online_users = map_size(room_presence)

      room
      |> Map.put(:online_users, online_users)
      |> Map.put(:last_active_users, room.last_active_users || [])
    end)
  end

  def join_room(room_id, password) do
    room = Repo.get(Room, room_id)

    IO.puts("\n=== Join Room Attempt ===")
    IO.puts("Room ID: #{room_id}")
    IO.puts("Room found: #{not is_nil(room)}")
    IO.puts("Is private: #{room && room.is_private}")
    IO.puts("Stored password: #{room && room.password}")
    IO.puts("Provided password: #{password}")

    cond do
      is_nil(room) ->
        {:error, :not_found}

      room.is_private && (is_nil(password) || password == "") ->
        {:error, :invalid_password}

      room.is_private && password != room.password ->
        {:error, :invalid_password}

      true ->
        {:ok, room}
    end
  end

  def create_room(attrs, current_user) do
    attrs = Map.put(attrs, "creator_id", current_user)
    create_room(attrs)
  end
end
