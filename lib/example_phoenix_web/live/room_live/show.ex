# lib/example_phoenix_web/live/room_live/show.ex
defmodule ExamplePhoenixWeb.RoomLive.Show do
  use ExamplePhoenixWeb, :live_view
  alias ExamplePhoenix.Chat
  alias ExamplePhoenix.Accounts.RateLimit
  import Phoenix.Component
  import Phoenix.HTML.Link
  require Logger

  # Add emoji list as a module attribute
  @emojis [
    {"smile", "😊"},
    {"laugh", "😄"},
    {"heart", "❤️"},
    {"thumbs_up", "👍"},
    {"clap", "👏"},
    {"fire", "🔥"},
    {"party", "🎉"},
    {"think", "🤔"},
    {"cool", "😎"},
    {"cry", "😢"},
    {"angry", "😠"},
    {"love", "😍"},
    {"wink", "😉"},
    {"pray", "🙏"},
    {"star", "⭐"}
  ]

  # เพิ่ม configuration สำหรับ upload
  @upload_options [
    accept: ~w(.jpg .jpeg .png .gif .webp .mp4 .mov .webm),
    max_entries: 1,
    max_file_size: 20_000_000,
    chunk_size: 128_000,
    chunk_timeout: 60_000,
    auto_upload: true
  ]

  @impl true
  def mount(%{"id" => id}, session, socket) do
    if connected?(socket) do
      # Subscribe to room topic
      Phoenix.PubSub.subscribe(ExamplePhoenix.PubSub, "room:#{id}")
    end

    case Chat.get_room(id) do
      {:ok, room} ->
        if connected?(socket) do
          ExamplePhoenixWeb.Endpoint.subscribe("room:#{room.id}")
        end

        client_ip = get_client_ip(socket)
        messages = Chat.list_messages(room.id)

        socket =
          socket
          |> assign(:current_user, session["user_name"])
          |> assign(:room, room)
          |> assign(:blocked, false)
          |> assign(:block_remaining_seconds, 0)
          |> assign(:client_ip, client_ip)
          |> assign(:current_message, "")
          |> assign(:message_ids, messages |> Enum.map(& &1.id) |> MapSet.new())
          |> stream(:messages, messages)
          |> assign(:show_emoji_modal, false)
          |> assign(:show_gallery, false)
          |> assign(:current_image, nil)
          |> assign(:uploading, false)
          |> assign(:upload_valid, false)
          |> assign(:input_focused, false)
          |> allow_upload(:media, @upload_options)
          |> assign(:emojis, @emojis)

        if connected?(socket) do
          check_block_status(socket)
        end

        {:ok, socket}

      {:error, _reason} ->
        {:ok,
         socket
         |> put_flash(:error, "ห้องสนนนาไม่มีอยู่")
         |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("logout", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "ออกจากห้องสนทนา")
     |> redirect(to: ~p"/auth")}
  end

  @impl true
  def handle_event("form-update", %{"message" => message}, socket) do
    {:noreply, assign(socket, current_message: message)}
  end

  @impl true
  def handle_event("handle_keydown", %{"key" => key, "value" => value}, socket) do
    case key do
      "Enter" ->
        if !socket.assigns.blocked do
          handle_send_message(socket)
        else
          {:noreply,
           socket
           |> put_flash(:error, format_block_time(socket.assigns.block_remaining_seconds))}
        end
      _ ->
        {:noreply, assign(socket, :current_message, value)}
    end
  end

  @impl true
  def handle_event("handle_keyup", %{"key" => "Enter", "shiftKey" => false}, socket) do
    handle_send_message(socket)
  end

  @impl true
  def handle_event("submit_message", %{"message" => content}, socket) when content != "" do
    message_params = %{
      "content" => content,
      "user_name" => socket.assigns.current_user,
      "user_avatar" => socket.assigns.current_user_avatar,
      "room_id" => socket.assigns.room.id
    }

    case Chat.create_message(message_params) do
      {:ok, message} ->
        # Broadcast the new message to all subscribers
        Phoenix.PubSub.broadcast(
          ExamplePhoenix.PubSub,
          "room:#{socket.assigns.room.id}",
          {:new_message, message}
        )

        {:noreply, assign(socket, :current_message, "")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "ไม่สามารถส่งข้อความได้")}
    end
  end

  # กรณีข้อความว่าง
  def handle_event("submit_message", _params, socket) do
    {:noreply, socket}
  end

  defp handle_youtube_url(socket, url) do
    video_id = extract_youtube_id(url)

    case get_youtube_metadata(url) do
      {:ok, metadata} ->
        create_social_message(socket, %{
          content: url,
          media_url: "https://img.youtube.com/vi/#{video_id}/maxresdefault.jpg",
          media_type: "youtube",
          title: metadata["title"]
        })
      _ ->
        create_regular_message(socket, url)
    end
  end

  defp get_youtube_metadata(url) do
    case HTTPoison.get("https://www.youtube.com/oembed?url=#{url}&format=json") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Jason.decode(body)
      _ ->
        {:error, "Could not fetch YouTube metadata"}
    end
  end

  defp handle_instagram_url(socket, url) do
    case Regex.run(~r/instagram\.com\/(p|reel)\/([^\/\?]+)/, url) do
      [_, type, post_id] ->
        create_social_message(socket, %{
          content: url,
          media_url: "https://www.instagram.com/p/#{post_id}/embed/",
          media_type: "instagram",
          title: "Instagram #{String.capitalize(type)}",
          platform: "Instagram"
        })
      _ ->
        create_regular_message(socket, url)
    end
  end

  defp handle_tiktok_url(socket, url) do
    case Regex.run(~r/tiktok\.com\/@[^\/]+\/video\/(\d+)/, url) do
      [_, video_id] ->
        create_social_message(socket, %{
          content: url,
          media_url: "https://www.tiktok.com/embed/v2/#{video_id}",
          media_type: "tiktok",
          title: "TikTok Video",
          platform: "TikTok"
        })
      _ ->
        create_regular_message(socket, url)
    end
  end

  defp handle_facebook_url(socket, url) do
    case get_facebook_metadata(url) do
      {:ok, metadata} ->
        create_social_message(socket, %{
          content: url,
          media_url: "https://www.facebook.com/plugins/post.php?href=#{URI.encode_www_form(url)}",
          media_type: "facebook",
          title: metadata.title || "Facebook Post",
          thumbnail_url: metadata.image,
          platform: "Facebook"
        })
      _ ->
        create_social_message(socket, %{
          content: url,
          media_url: "https://www.facebook.com/plugins/post.php?href=#{URI.encode_www_form(url)}",
          media_type: "facebook",
          title: "Facebook Post",
          platform: "Facebook"
        })
    end
  end

  defp get_facebook_metadata(url) do
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        # ดึง metadata จาก Open Graph tags
        title = extract_meta_content(body, "og:title")
        image = extract_meta_content(body, "og:image")
        description = extract_meta_content(body, "og:description")

        {:ok, %{
          title: title,
          image: image,
          description: description
        }}
      _ ->
        :error
    end
  end

  defp extract_meta_content(html, property) do
    case Floki.parse_document(html) do
      {:ok, document} ->
        document
        |> Floki.find("meta[property='#{property}']")
        |> Floki.attribute("content")
        |> List.first()
      _ ->
        nil
    end
  end

  defp handle_twitter_url(socket, url) do
    case Regex.run(~r/(?:twitter\.com|x\.com)\/[^\/]+\/status\/(\d+)/, url) do
      [_, tweet_id] ->
        create_social_message(socket, %{
          content: url,
          media_url: "https://platform.twitter.com/embed/Tweet.html?id=#{tweet_id}",
          media_type: "twitter",
          title: "X Post",
          preview_url: url,
          platform: "X"
        })
      _ ->
        create_regular_message(socket, url)
    end
  end

  defp create_social_message(socket, params) do
    message_params = Map.merge(params, %{
      user_name: socket.assigns.current_user,
      room_id: socket.assigns.room.id,
      content_type: params.media_type
    })

    case Chat.create_message(message_params) do
      {:ok, message} ->
        {:noreply,
         socket
         |> stream_insert(:messages, message, at: -1)
         |> assign(:current_message, "")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "ไม่สามารถส่งข้อความได้")}
    end
  end

  defp create_regular_message(socket, content) do
    case Chat.create_message(%{
      content: content,
      user_name: socket.assigns.current_user,
      room_id: socket.assigns.room.id
    }) do
      {:ok, message} ->
        {:noreply,
         socket
         |> stream_insert(:messages, message, at: -1)
         |> assign(:current_message, "")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "ไม่สามารถส่งข้อความได้")}
    end
  end

  defp extract_youtube_id(url) do
    case Regex.run(~r/(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]+)/, url) do
      [_, id] -> id
      _ -> nil
    end
  end

  @impl true
  def handle_event("open_emoji", _params, socket) do
    {:noreply, assign(socket, :show_emoji_modal, true)}
  end

  @impl true
  def handle_event("close_emoji", _params, socket) do
    {:noreply, assign(socket, :show_emoji_modal, false)}
  end

  @impl true
  def handle_event("select_emoji", %{"emoji" => emoji}, socket) do
    current_message = socket.assigns.current_message || ""
    {:noreply,
     socket
     |> assign(:current_message, current_message <> emoji)}
  end

  @impl true
  def handle_event("upload_media", _params, socket) do
    {:noreply, assign(socket, :uploading, true)}
  end

  @impl true
  def handle_event("cancel_upload", %{"value" => _}, socket) do
    {:noreply,
     socket
     |> assign(:uploading, false)}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply,
     socket
     |> cancel_upload(:media, ref)
     |> assign(:uploading, false)}
  end

  @impl true
  def handle_event("validate_upload", params, socket) do
    Logger.info("Validating upload: #{inspect(params)}")

    {socket, valid?} =
      case socket.assigns.uploads.media.entries do
        [] ->
          {socket, false}
        [entry | _] ->
          Logger.info("Validating entry: #{inspect(entry)}")
          case validate_upload(entry) do
            :ok -> {socket, true}
            {:error, message} ->
              {socket |> put_flash(:error, message), false}
          end
      end

    {:noreply, assign(socket, :upload_valid, valid?)}
  end

  defp validate_upload(entry) do
    valid_types = ~w(
      image/jpeg image/png image/gif image/webp
      video/mp4 video/quicktime video/webm
    )

    cond do
      entry.client_size > 20_000_000 ->
        {:error, "File size must be less than 20MB"}

      entry.client_type not in valid_types ->
        {:error, "Invalid file type. Supported types: JPG, PNG, GIF, WEBP, MP4, MOV, WEBM"}

      true ->
        :ok
    end
  end

  @impl true
  def handle_event("save_upload", _params, socket) do
    Logger.info("Save upload triggered")

    case socket.assigns.uploads.media.entries do
      [_entry | _] ->
        consume_uploaded_entries(socket, :media, fn %{path: path}, entry ->
          case upload_file(path, entry) do
            {:ok, url} ->
              message_params = %{
                user_name: socket.assigns.current_user,
                room_id: socket.assigns.room.id,
                media_url: url,
                media_type: get_media_type(entry.client_type),
                content_type: entry.client_type,
                title: entry.client_name
              }

              case Chat.create_message(message_params) do
                {:ok, message} -> {:ok, message}
                {:error, _} -> {:error, "ไม่สามารถบันทึกข้อความได้"}
              end

            {:error, _} -> {:error, "อัพโหลดไฟล์ไม่สำเร็จ"}
          end
        end)
        |> case do
          [{:ok, message}] ->
            {:noreply,
             socket
             |> stream_insert(:messages, message, at: -1)
             |> assign(:uploading, false)
             |> put_flash(:info, "อัพโหลดสำเร็จ")}

          [{:error, reason}] ->
            {:noreply,
             socket
             |> assign(:uploading, false)
             |> put_flash(:error, reason)}

          _ ->
            {:noreply,
             socket
             |> assign(:uploading, false)
             |> put_flash(:error, "เกิดข้อผิดพลาดที่ไม่คาดคิด")}
        end

      [] ->
        {:noreply,
         socket
         |> put_flash(:error, "ไม่พบไฟล์ที่จะอัพโหลด")}
    end
  end

  @impl true
  def handle_event("cancel_entry", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :media, ref)}
  end

  @impl true
  def handle_info(%{event: "new_message", payload: message}, socket) do
    if !MapSet.member?(socket.assigns.message_ids, message.id) do
      {:noreply,
       socket
       |> update(:message_ids, &MapSet.put(&1, message.id))
       |> stream_insert(:messages, message, at: -1)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    if !MapSet.member?(socket.assigns.message_ids, message.id) do
      {:noreply,
       socket
       |> update(:message_ids, &MapSet.put(&1, message.id))
       |> stream_insert(:messages, message, at: -1)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:block_status, blocked, remaining_seconds}, socket) do
    {:noreply,
     socket
     |> assign(:blocked, blocked)
     |> assign(:block_remaining_seconds, remaining_seconds)}
  end

  @impl true
  def handle_info({:progress, ref, progress}, socket) do
    {:noreply, push_event(socket, "upload_progress", %{
      ref: ref,
      progress: progress
    })}
  end

  defp handle_send_message(socket) do
    message = socket.assigns.current_message
    media_entries = socket.assigns.uploads.media.entries

    cond do
      # กรณีมีการอัพโหลดไฟล์
      length(media_entries) > 0 ->
        [entry | _] = media_entries

        if entry.done? do
          consume_uploaded_entries(socket, :media, fn %{path: path}, entry ->
            ext = Path.extname(entry.client_name)
            filename = "#{System.system_time()}-#{:crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)}#{ext}"

            case ExamplePhoenix.Uploads.upload_file(%{
              path: path,
              filename: filename,
              content_type: entry.client_type
            }) do
              {:ok, url} ->
                message_params = %{
                  content: if(byte_size(message) > 0, do: message, else: nil),
                  user_name: socket.assigns.current_user,
                  room_id: socket.assigns.room.id,
                  media_url: url,
                  media_type: get_media_type(entry.client_type),
                  content_type: entry.client_type,
                  title: entry.client_name
                }

                case Chat.create_message(message_params) do
                  {:ok, new_message} -> {:ok, new_message}
                  {:error, _} -> {:error, "ไม่สามารถส่งข้อความได้"}
                end

              {:error, _} -> {:error, "อัพโหลดไฟล์ไม่สำเร็จ"}
            end
          end)
          |> case do
            [{:ok, message}] ->
              {:noreply,
               socket
               |> stream_insert(:messages, message, at: -1)
               |> assign(:current_message, "")
               |> assign(:uploading, false)}

            [{:error, reason}] ->
              {:noreply,
               socket
               |> put_flash(:error, reason)
               |> assign(:uploading, false)}
          end
        else
          {:noreply,
           socket
           |> put_flash(:error, "กรุณารอให้ไฟล์อัพโหลดเสร็จสมบูรณ์")}
        end

      # กรณีมีข้อความ
      byte_size(message) > 0 ->
        case Chat.create_message(%{
          content: message,
          user_name: socket.assigns.current_user,
          room_id: socket.assigns.room.id
        }) do
          {:ok, new_message} ->
            {:noreply,
             socket
             |> stream_insert(:messages, new_message, at: -1)
             |> assign(:current_message, "")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "ไม่สามารถส่งข้อความได้")}
        end

      true ->
        {:noreply, socket}
    end
  end

  defp format_block_time(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)

    cond do
      minutes > 0 ->
        "คุณถูกแบน อีก #{minutes} นาที #{remaining_seconds} วินาที จึงจะสามารถส่งข้อความได้"
      true ->
        "คุณถูกแบน อีก #{remaining_seconds} วินาที จึจะสามารถส่งข้อความได้"
    end
  end
  defp format_block_time(_), do: "คุณถูกแบน"

  defp check_block_status(socket) do
    client_ip = socket.assigns.client_ip || "unknown"

    case ExamplePhoenix.Accounts.RateLimit.check_rate_limit(client_ip) do
      {:error, remaining_seconds} ->
        Process.send_after(self(), {:check_block_status}, 1000)
        {:noreply,
         socket
         |> assign(:blocked, true)
         |> assign(:block_remaining_seconds, remaining_seconds)}

      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:blocked, false)
         |> assign(:block_remaining_seconds, 0)}
    end
  end

  @impl true
  def handle_info({:check_block_status}, socket) do
    if socket.assigns.blocked do
      new_remaining = max(0, socket.assigns.block_remaining_seconds - 1)

      if new_remaining > 0 do
        Process.send_after(self(), {:check_block_status}, 1000)
        {:noreply, assign(socket, :block_remaining_seconds, new_remaining)}
      else
        {:noreply,
         socket
         |> assign(:blocked, false)
         |> assign(:block_remaining_seconds, 0)}
      end
    else
      {:noreply, socket}
    end
  end

  defp get_client_ip(socket) do
    require Logger

    peer_data = get_connect_info(socket, :peer_data)
    Logger.info("Peer Data: #{inspect(peer_data)}")

    case peer_data do
      %{address: {127, 0, 0, 1}} ->
        "127.0.0.1"  # localhost
      %{address: address} ->
        ip = address |> :inet.ntoa() |> to_string()
        Logger.info("Client IP from peer_data: #{ip}")
        ip
      _ ->
        forwarded_for = get_connect_info(socket, :x_forwarded_for)
        Logger.info("X-Forwarded-For: #{inspect(forwarded_for)}")

        case forwarded_for do
          [ip | _] ->
            Logger.info("Client IP from x_forwarded_for: #{ip}")
            ip
          _ ->
            Logger.info("Using localhost IP for development")
            "127.0.0.1"  # ใช้ localhost แทน unknown ำหรับการพัฒนา
        end
    end
  end

  defp get_ngrok_ip(headers) when is_list(headers) do
    case List.keyfind(headers, "ngrok-client-ip", 0) do
      {_, value} -> String.trim(value)
      _ -> nil
    end
  end
  defp get_ngrok_ip(_), do: nil

  defp get_forwarded_for(headers) when is_list(headers) do
    case List.keyfind(headers, "x-forwarded-for", 0) do
      {_, value} ->
        value
        |> String.split(",")
        |> List.first()
        |> String.trim()
      _ -> nil
    end
  end
  defp get_forwarded_for(_), do: nil

  defp get_real_ip(headers) when is_list(headers) do
    case List.keyfind(headers, "x-real-ip", 0) do
      {_, value} -> String.trim(value)
      _ -> nil
    end
  end
  defp get_real_ip(_), do: nil

  defp format_message_time(datetime) do
    Calendar.strftime(datetime, "%H:%M")
  end

  defp get_media_type(content_type) do
    cond do
      String.starts_with?(content_type, "image/") -> "image"
      String.starts_with?(content_type, "video/") -> "video"
      true -> "file"
    end
  end

  defp format_file_size(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_000_000 -> "#{Float.round(bytes / 1_000_000, 1)} MB"
      bytes >= 1_000 -> "#{Float.round(bytes / 1_000, 1)} KB"
      true -> "#{bytes} B"
    end
  end
  defp format_file_size(_), do: "Unknown size"

  # Helper function to remove empty content
  defp maybe_remove_empty_content(params) do
    case params do
      %{content: content} when is_binary(content) ->
        if String.trim(content) == "", do: Map.delete(params, :content), else: params
      _ ->
        params
    end
  end

  defp handle_text_message(socket, message) when byte_size(message) > 0 do
    case Chat.create_message(%{
      content: message,
      user_name: socket.assigns.current_user,
      room_id: socket.assigns.room.id
    }) do
      {:ok, new_message} ->
        {:noreply,
         socket
         |> stream_insert(:messages, new_message, at: -1)
         |> assign(:current_message, "")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "ไม่พามารถส่งข้อความได้")}
    end
  end

  defp handle_media_message(socket, message, entry) when is_struct(entry, Phoenix.LiveView.UploadEntry) do
    if entry.done? do
      ext = Path.extname(entry.client_name)
      filename = "#{System.system_time()}-#{:crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)}#{ext}"

      case ExamplePhoenix.Uploads.upload_file(%{
        path: entry.path,
        filename: filename,
        content_type: entry.client_type
      }) do
        {:ok, url} ->
          message_params = %{
            content: message,
            user_name: socket.assigns.current_user,
            room_id: socket.assigns.room.id,
            media_url: url,
            media_type: get_media_type(entry.client_type),
            content_type: entry.client_type
          }

          case Chat.create_message(message_params) do
            {:ok, new_message} ->
              {:noreply,
               socket
               |> stream_insert(:messages, new_message, at: -1)
               |> assign(:current_message, "")
               |> assign(:uploading, false)}

            {:error, _} ->
              {:noreply,
               socket
               |> put_flash(:error, "ไม่พามารถส่งข้อความได้")
               |> assign(:uploading, false)}
          end

        {:error, _} ->
          {:noreply,
           socket
           |> put_flash(:error, "อัพโหลดไฟล์ไม่สำเร็จ")
           |> assign(:uploading, false)}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "กรุณารอให้ไฟล์อัพโหลดเสร็จสมบูรณ์")}
    end
  end

  defp handle_media_message(socket, _message, _) do
    {:noreply,
     socket
     |> put_flash(:error, "ไม่รอมอัพพโหดไฟล์ห๗ี่อัพโหลด")
     |> assign(:uploading, false)}
  end

  defp handle_progress(:media, entry, socket) do
    if entry.done? do
      {:noreply, socket}
    else
      # ส่ง progress ทุ 10%
      if rem(entry.progress, 10) == 0 do
        {:noreply, socket |> push_event("upload_progress", %{
          ref: entry.ref,
          progress: entry.progress
        })}
      else
        {:noreply, socket}
      end
    end
  end

  # Fix the uploading? function
  defp uploading?(socket) do
    socket.assigns.uploads.media.entries
    |> Enum.any?(fn entry -> not entry.done? end)
  end

  # แยการจัดการข้อควาออกมา
  defp handle_message_submit(message, socket) do
    cond do
      String.match?(message, ~r/^https?:\/\//) ->
        case get_url_metadata(message) do
          {:ok, metadata} ->
            message_params = %{
              content: message,
              user_name: socket.assigns.current_user,
              room_id: socket.assigns.room.id,
              media_url: metadata.media_url,
              media_type: metadata.media_type,
              content_type: metadata.media_type,
              title: metadata.title || URI.parse(message).host || message
            }

            case Chat.create_message(message_params) do
              {:ok, _message} -> {:ok, assign(socket, :current_message, "")}
              {:error, _} -> create_text_message(message, socket)
            end

          _ -> create_text_message(message, socket)
        end

      true ->
        create_text_message(message, socket)
    end
  end

  # ปรับปรุงฟังก์ชัน handle_uploaded_file
  defp handle_uploaded_file(path, entry) do
    Logger.info("Handling file upload: #{entry.client_name}")

    ext = Path.extname(entry.client_name)
    filename = "#{System.system_time()}-#{:crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)}#{ext}"

    upload_params = %{
      path: path,
      filename: filename,
      content_type: entry.client_type
    }

    Logger.info("Upload params: #{inspect(upload_params)}")

    case ExamplePhoenix.Uploads.upload_file(upload_params) do
      {:ok, url} ->
        Logger.info("File uploaded successfully to: #{url}")
        {:ok, url}
      {:error, reason} = error ->
        Logger.error("Upload failed: #{inspect(reason)}")
        error
    end
  end

  defp upload_file(path, entry) do
    ext = Path.extname(entry.client_name)
    filename = "#{System.system_time()}-#{:crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)}#{ext}"

    case ExamplePhoenix.Uploads.upload_file(%{
      path: path,
      filename: filename,
      content_type: entry.client_type
    }) do
      {:ok, url} -> {:ok, url}
      error -> error
    end
  end

  # เพิ่มฟังก์ชัน handle_upload_result
  defp handle_upload_result(results, socket) do
    case results do
      [{:ok, message}] ->
        {:noreply,
         socket
         |> assign(:current_message, "")
         |> assign(:uploading, false)
         |> stream_insert(:messages, message, at: -1)}

      [{:error, reason}] ->
        {:noreply,
         socket
         |> put_flash(:error, reason)
         |> assign(:uploading, false)}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "เกิดข้อผิดพลาดที่ไม่คาดคิด")
         |> assign(:uploading, false)}
    end
  end

  @doc false
  defp create_media_message(content, url, content_type, socket) do
    message_params = %{
      content: content,
      room_id: socket.assigns.room.id,
      user_name: socket.assigns.current_user,
      media_url: url,
      media_type: get_media_type(content_type),
      content_type: content_type
    }

    case Chat.create_message(message_params) do
      {:ok, _message} ->
        {:ok,
         socket
         |> assign(:current_message, "")
         |> assign(:uploading, false)}
      {:error, _} ->
        {:error, "Failed to send message", socket}
    end

  end

  # เพิ่มการจัดการ error ที่ดีขึ้น
  defp handle_upload_error(socket, error) do
    error_message = case error do
      :too_large -> "ไฟล��มีขนาดใหญ่เกินไป (สูงสุด 20MB)"
      :too_many_files -> "สามารถอัพโหลดได้ครั้งละ 1 ไฟล์เท่านั้น"
      message when is_binary(message) -> message
      _ -> "เกิดข้อผิดพลาดในการอัพโหลด กรุณาลองใหม่อีกครั้ง"
    end

    {:noreply,
     socket
     |> put_flash(:error, error_message)
     |> assign(:uploading, false)}
  end

  # สร้งข้อความปกติ
  @doc false
  defp create_text_message("", socket), do: {:ok, socket}
  defp create_text_message(content, socket) do
    case Chat.create_message(%{
      content: content,
      room_id: socket.assigns.room.id,
      user_name: socket.assigns.current_user
    }) do
      {:ok, _message} -> {:ok, assign(socket, current_message: "")}
      {:error, _} -> {:error, "Failed to send message", socket}
    end
  end

  @impl true
  def handle_event("view_all_images", %{"images" => images_json}, socket) do
    case Jason.decode(images_json) do
      {:ok, images} ->
        {:noreply,
         socket
         |> assign(:show_gallery, true)
         |> assign(:gallery_images, images)
         |> assign(:current_gallery_index, 0)}
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_gallery", _, socket) do
    {:noreply,
     socket
     |> assign(:show_gallery, false)
     |> assign(:gallery_images, [])
     |> assign(:current_gallery_index, 0)
     |> assign(:current_image, nil)}
  end

  @impl true
  def handle_event("prev_image", _, socket) do
    new_index = max(0, socket.assigns.current_gallery_index - 1)
    {:noreply, assign(socket, :current_gallery_index, new_index)}
  end

  @impl true
  def handle_event("next_image", _, socket) do
    new_index = min(
      length(socket.assigns.gallery_images) - 1,
      socket.assigns.current_gallery_index + 1
    )
    {:noreply, assign(socket, :current_gallery_index, new_index)}
  end

  @impl true
  def handle_event("view_image", %{"url" => url}, socket) do
    {:noreply, assign(socket,
      show_gallery: true,
      current_image: url
    )}
  end

  # เพิ่ม function ใหม่สำหรับตรจสอบ YouTube URL
  defp is_youtube_url?(content) do
    youtube_regex = ~r/(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]+)/
    String.match?(content, youtube_regex)
  end

  # เพิ่ม function สำหรับดึง video ID
  defp extract_youtube_id(url) do
    youtube_regex = ~r/(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]+)/
    case Regex.run(youtube_regex, url) do
      [_, video_id] -> {:ok, video_id}
      _ -> :error
    end
  end

  # ปรับปรุงฟังก์ชัน get_url_metadata
  defp get_url_metadata(url) do
    Logger.info("Getting metadata for URL: #{url}")

    cond do
      # YouTube
      String.match?(url, ~r/(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]+)/) ->
        video_id = case Regex.run(~r/(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]+)/, url) do
          [_, id] -> id
          _ -> nil
        end

        if video_id do
          case HTTPoison.get("https://www.youtube.com/oembed?url=#{url}&format=json") do
            {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
              case Jason.decode(body) do
                {:ok, data} ->
                  {:ok, %{
                    title: data["title"],
                    media_url: "https://img.youtube.com/vi/#{video_id}/maxresdefault.jpg",
                    media_type: "youtube"
                  }}
                _ -> {:error, "Invalid YouTube response"}
              end
            _ -> {:error, "Failed to fetch YouTube data"}
          end
        else
          {:error, "Invalid YouTube URL"}
        end

      # Instagram
      String.match?(url, ~r/instagram\.com\/(p|reel)\/([^\/\?]+)/) ->
        [_, type, post_id] = Regex.run(~r/instagram\.com\/(p|reel)\/([^\/\?]+)/, url)
        {:ok, %{
          title: "Instagram #{String.capitalize(type)}",
          media_url: "https://www.instagram.com/#{type}/#{post_id}/embed",
          media_type: "instagram"
        }}

      # TikTok
      String.match?(url, ~r/tiktok\.com\/@[^\/]+\/video\/(\d+)/) ->
        [_, video_id] = Regex.run(~r/tiktok\.com\/@[^\/]+\/video\/(\d+)/, url)
        {:ok, %{
          title: "TikTok Video",
          media_url: "https://www.tiktok.com/embed/v2/#{video_id}",
          media_type: "tiktok"
        }}

      # Twitter/X
      String.match?(url, ~r/(?:twitter\.com|x\.com)\/[^\/]+\/status\/(\d+)/) ->
        [_, tweet_id] = Regex.run(~r/(?:twitter\.com|x\.com)\/[^\/]+\/status\/(\d+)/, url)
        {:ok, %{
          title: "X Post",
          media_url: "https://platform.twitter.com/embed/Tweet.html?id=#{tweet_id}",
          media_type: "twitter"
        }}

      # Facebook
      String.match?(url, ~r/facebook\.com/) ->
        encoded_url = URI.encode_www_form(url)
        {:ok, %{
          title: "Facebook Post",
          media_url: "https://www.facebook.com/plugins/post.php?href=#{encoded_url}&show_text=true&width=500",
          media_type: "facebook"
        }}

      true ->
        {:error, "Unsupported URL"}
    end
  end

  # ปรับปรุงฟังก์ชัน handle_media_upload
  defp handle_media_upload(message, socket) do
    Logger.info("Handling media upload with message: #{inspect(message)}")

    [entry | _] = socket.assigns.uploads.media.entries

    if entry.done? do
      consume_uploaded_entries(socket, :media, fn %{path: path}, _entry ->
        case upload_file(path, entry) do
          {:ok, url} ->
            Logger.info("File uploaded successfully to: #{url}")

            message_params = %{
              content: if(byte_size(message || "") > 0, do: message, else: nil),
              user_name: socket.assigns.current_user,
              room_id: socket.assigns.room.id,
              media_url: url,
              media_type: get_media_type(entry.client_type),
              content_type: entry.client_type,
              title: entry.client_name
            }
            |> maybe_remove_empty_content()

            case Chat.create_message(message_params) do
              {:ok, new_message} ->
                Logger.info("Message created successfully")
                {:ok, new_message}
              {:error, reason} ->
                Logger.error("Failed to create message: #{inspect(reason)}")
                {:error, "ไม่สามารถบันทึกข้อความได้"}
            end

          {:error, reason} ->
            Logger.error("Upload failed: #{inspect(reason)}")
            {:error, "อัพโหลดไฟล์ไม่สำเร็จ"}
        end
      end)
      |> case do
        [{:ok, new_message}] ->
          {:noreply,
           socket
           |> stream_insert(:messages, new_message, at: -1)
           |> assign(:current_message, "")
           |> assign(:uploading, false)}

        [{:error, reason}] ->
          {:noreply,
           socket
           |> put_flash(:error, reason)
           |> assign(:uploading, false)}

        _ ->
          {:noreply,
           socket
           |> put_flash(:error, "เกิดข้อผิดพลาดที่ไม่คาดคิด")
           |> assign(:uploading, false)}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "กรุณารอให้อัพโหลดเสร็จสมบูรณ์")}
    end
  end

  # เพิ่ม event handlers
  def handle_event("focus_input", _, socket) do
    {:noreply, assign(socket, :input_focused, true)}
  end

  def handle_event("blur_input", _, socket) do
    {:noreply, assign(socket, :input_focused, false)}
  end

  def handle_event("send_message", %{"content" => content}, socket) do
    message_params = %{
      "content" => content,
      "user_name" => socket.assigns.current_user,
      "user_avatar" => socket.assigns.current_user_avatar,
      "room_id" => socket.assigns.room.id
    }

    case Chat.create_message(message_params) do
      {:ok, _message} ->
        {:noreply, socket |> assign(:current_message, "")}
      {:error, _changeset} ->
        {:noreply, socket |> put_flash(:error, "ไม่สามารถส่งข้อความได้")}
    end
  end

end
