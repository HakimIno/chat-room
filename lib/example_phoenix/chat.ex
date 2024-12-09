# lib/example_phoenix/chat.ex
defmodule ExamplePhoenix.Chat do
  import Ecto.Query, warn: false
  alias ExamplePhoenix.Repo
  alias ExamplePhoenix.Chat.{Room, Message, RoomRateLimit}

  # กำหนดค่า rate limit
  @max_rooms_per_hour 5
  @block_duration_hours 24

  # เพิ่ม cache สำหรับ URL metadata
  @cache_ttl :timer.hours(24) # เก็บ cache 24 ชั่วโมง

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
    user_id = attrs["creator_id"]

    case check_rate_limit(user_id) do
      {:ok, _} ->
        # สร้างห้องตามปกติ
        %Room{}
        |> Room.changeset(attrs)
        |> Repo.insert()
        |> case do
          {:ok, _room} = result ->
            increment_attempt(user_id)
            result
          error ->
            error
        end

      {:error, :rate_limited} ->
        {:error, :rate_limited}
    end
  end

  defp check_rate_limit(user_id) do
    now = NaiveDateTime.local_now()
    one_hour_ago = NaiveDateTime.add(now, -1 * 3600, :second)
    block_expires_at = NaiveDateTime.add(now, -1 * @block_duration_hours * 3600, :second)

    rate_limit = Repo.get_by(RoomRateLimit, user_id: user_id)

    cond do
      is_nil(rate_limit) ->
        {:ok, create_rate_limit(user_id)}

      rate_limit.last_attempt_at < block_expires_at ->
        # รีเซ็หลังจากพ้นระยะเวลาบล็อก
        {:ok, reset_rate_limit(rate_limit)}

      rate_limit.last_attempt_at < one_hour_ago ->
        # รีเซ็ตหลังจากพ้น 1 ชั่วโมง
        {:ok, reset_rate_limit(rate_limit)}

      rate_limit.attempt_count >= @max_rooms_per_hour ->
        {:error, :rate_limited}

      true ->
        {:ok, rate_limit}
    end
  end

  defp create_rate_limit(user_id) do
    %RoomRateLimit{}
    |> RoomRateLimit.changeset(%{
      user_id: user_id,
      attempt_count: 0,
      last_attempt_at: NaiveDateTime.local_now()
    })
    |> Repo.insert!()
  end

  defp reset_rate_limit(rate_limit) do
    rate_limit
    |> RoomRateLimit.changeset(%{
      attempt_count: 0,
      last_attempt_at: NaiveDateTime.local_now()
    })
    |> Repo.update!()
  end

  defp increment_attempt(user_id) do
    from(r in RoomRateLimit, where: r.user_id == ^user_id)
    |> Repo.update_all(
      inc: [attempt_count: 1],
      set: [last_attempt_at: NaiveDateTime.local_now()]
    )
  end

  def get_remaining_time_for_block(user_id) do
    case Repo.get_by(RoomRateLimit, user_id: user_id) do
      nil ->
        0

      rate_limit ->
        now = NaiveDateTime.local_now()
        block_expires_at = NaiveDateTime.add(rate_limit.last_attempt_at, @block_duration_hours * 3600, :second)

        if NaiveDateTime.compare(block_expires_at, now) == :gt do
          NaiveDateTime.diff(block_expires_at, now, :second)
        else
          0
        end
    end
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
        # Broadcast ข้อความใหม่ไปยังทุคนในห้อง
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

  def get_url_metadata(url) do
    cache_key = "url_metadata:#{url}"

    case Cachex.get(:my_cache, cache_key) do
      {:ok, nil} ->
        # ถ้าไม่มีใน cache ให้ดึงข้อมูลใหม่
        metadata = fetch_url_metadata(url)
        Cachex.put(:my_cache, cache_key, metadata, ttl: @cache_ttl)
        metadata

      {:ok, metadata} ->
        # ถ้ามีใน cache ให้ใช้ข้อมูลเดิม
        metadata
    end
  end

  def create_url_message(attrs) do
    # สร้าง message ก่อนแบบไม่มี metadata
    {:ok, message} = create_message(attrs)

    # schedule background job
    %{url: attrs.content, message_id: message.id}
    |> FetchUrlMetadataWorker.new()
    |> Oban.insert()

    {:ok, message}
  end

  def fetch_url_metadata(url) do
    # เพิ่ม timeout และ error handling
    try do
      Task.await(Task.async(fn ->
        case HTTPoison.get(url, [], timeout: 5000, recv_timeout: 5000) do
          {:ok, response} -> parse_metadata(response)
          {:error, _} -> default_metadata()
        end
      end), 6000)
    catch
      :exit, _ -> default_metadata()
    end
  end

  defp default_metadata do
    %{
      title: nil,
      media_url: nil,
      media_type: "link"
    }
  end

  defp parse_metadata(response) do
    # Parse HTML using Floki
    case Floki.parse_document(response.body) do
      {:ok, document} ->
        %{
          title: extract_title(document),
          media_url: extract_media_url(document),
          media_type: determine_media_type(document)
        }
      _ -> default_metadata()
    end
  end

  defp extract_title(document) do
    document
    |> Floki.find("title")
    |> Floki.text()
    |> case do
      "" -> nil
      title -> title
    end
  end

  defp extract_media_url(document) do
    document
    |> Floki.find("meta[property='og:image']")
    |> Floki.attribute("content")
    |> List.first()
  end

  defp determine_media_type(document) do
    cond do
      has_video_metadata?(document) -> "video"
      has_image_metadata?(document) -> "image"
      true -> "link"
    end
  end

  defp has_video_metadata?(document) do
    document
    |> Floki.find("meta[property='og:video']")
    |> Enum.any?()
  end

  defp has_image_metadata?(document) do
    document
    |> Floki.find("meta[property='og:image']")
    |> Enum.any?()
  end
end
