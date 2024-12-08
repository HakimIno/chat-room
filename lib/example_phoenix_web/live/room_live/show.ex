# lib/example_phoenix_web/live/room_live/show.ex
defmodule ExamplePhoenixWeb.ChatLive.Show do
  use ExamplePhoenixWeb, :live_view
  alias ExamplePhoenix.Chat
  import Phoenix.Component
  import Phoenix.HTML.Link
  import Phoenix.LiveView.Helpers
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
    case Chat.get_room(id) do
      {:ok, room} ->
        if connected?(socket) do
          ExamplePhoenixWeb.Endpoint.subscribe("room:#{room.id}")
        end

        # ดึงข้อความและแปลง media_url ก่อนส่งเข้า stream
        messages =
          Chat.list_messages(room.id, 100)
          |> Enum.map(fn message ->
            # แปลง media_url ให้เป็น nil ถ้าเป็น list ว่าง
            media_url = case message.media_url do
              url when is_binary(url) -> url
              _ -> nil  # แปลงทุกกรณีอื่นๆ (รวมถึง [] และ nil) เป็น nil
            end

            # สร้าง message ใหม่ด้วย media_url ที่แปลงแล้ว
            %{message |
              media_url: media_url,
              media_type: (if media_url, do: message.media_type, else: nil),
              content_type: (if media_url, do: message.content_type, else: nil)
            }
          end)

        socket =
          socket
          |> assign(:current_user, session["user_name"])
          |> assign(:room, room)
          |> assign(:messages, [])
          |> assign(:message_ids, MapSet.new())
          |> assign(:current_message, "")
          |> assign(:blocked, false)
          |> assign(:block_remaining_seconds, 0)
          |> assign(:show_emoji_modal, false)
          |> assign(:client_ip, get_client_ip(socket))
          |> assign(:emojis, @emojis)
          |> assign(:uploading, false)
          |> allow_upload(:media, @upload_options)
          |> assign(:show_gallery, false)
          |> assign(:current_image, nil)

        {:ok,
         socket
         |> stream(:messages, messages)}

      {:error, _reason} ->
        {:ok,
         socket
         |> put_flash(:error, "ห้องสนทนาไม่มีอยู่")
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
    {:noreply, assign(socket, :current_message, message)}
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
  def handle_event("submit_message", %{"message" => message}, socket) do
    # ตรวจสอบว่ามีการอัพโหลดไฟล์หาอยู่หรือไม่
    if uploading?(socket) do
      {:noreply, put_flash(socket, :error, "Please wait for file upload to complete")}
    else
      case handle_message_submit(message, socket) do
        {:ok, socket} ->
          {:noreply, socket}
        {:error, message, socket} ->
          {:noreply, put_flash(socket, :error, message)}
      end
    end
  end

  @impl true
  def handle_event("submit_message", _params, socket) do
    {:noreply, socket}
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
  def handle_event("validate_upload", %{"message" => message}, socket) do
    {:noreply, assign(socket, :current_message, message)}
  end

  @impl true
  def handle_event("save_upload", %{"message" => message}, socket) do
    Logger.info("Handling save_upload event")
    Logger.info("Message: #{message}")
    Logger.info("Uploads: #{inspect(socket.assigns.uploads.media.entries)}")

    case socket.assigns.uploads.media.entries do
      [entry | _] ->
        Logger.info("Processing upload entry: #{inspect(entry)}")

        consume_uploaded_entries(socket, :media, fn %{path: path}, _entry ->
          ext = Path.extname(entry.client_name)
          filename = "#{System.system_time()}-#{:crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)}#{ext}"

          Logger.info("Attempting to upload file: #{filename}")
          Logger.info("File path: #{path}")
          Logger.info("Content type: #{entry.client_type}")

          case ExamplePhoenix.Uploads.upload_file(%{
            path: path,
            filename: filename,
            content_type: entry.client_type
          }) do
            {:ok, url} ->
              Logger.info("File uploaded successfully to: #{url}")

              message_params = %{
                content: if(message == "", do: nil, else: message),
                user_name: socket.assigns.current_user,
                room_id: socket.assigns.room.id,
                media_url: url,
                media_type: get_media_type(entry.client_type),
                content_type: entry.client_type
              }

              case Chat.create_message(message_params) do
                {:ok, _message} -> {:ok, url}
                {:error, changeset} ->
                  Logger.error("Failed to create message: #{inspect(changeset)}")
                  {:error, "Failed to save message"}
              end

            {:error, reason} ->
              Logger.error("Failed to upload file: #{inspect(reason)}")
              {:error, "Failed to upload file"}
          end
        end)
        |> case do
          [{:ok, _url}] ->
            {:noreply,
             socket
             |> assign(:uploading, false)
             |> assign(:current_message, "")}

          [{:error, reason}] ->
            {:noreply,
             socket
             |> put_flash(:error, reason)
             |> assign(:uploading, false)}

          _ ->
            {:noreply,
             socket
             |> put_flash(:error, "Upload failed")
             |> assign(:uploading, false)}
        end

      [] ->
        {:noreply,
         socket
         |> put_flash(:error, "No file selected")
         |> assign(:uploading, false)}
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
        media_urls =
          consume_uploaded_entries(socket, :media, fn %{path: path}, entry ->
            ext = Path.extname(entry.client_name)
            filename = "#{System.system_time()}-#{:crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)}#{ext}"

            case ExamplePhoenix.Uploads.upload_file(%{
              path: path,
              filename: filename,
              content_type: entry.client_type
            }) do
              {:ok, url} -> {:ok, url}
              {:error, reason} -> {:error, reason}
            end
          end)

        case Enum.split_with(media_urls, fn result ->
          case result do
            {:ok, _} -> true
            {:error, _} -> false
          end
        end) do
          {successful, []} ->
            # สร้างข้อความพร้อมรูปภาพทั้งหมด
            url = successful |> List.first() |> elem(1)
            message_params = %{
              content: if(byte_size(message) > 0, do: message, else: nil),
              user_name: socket.assigns.current_user,
              room_id: socket.assigns.room.id,
              media_url: url,  # ส่งเป็น list ของ URLs
              media_type: "image",
              content_type: List.first(media_entries).client_type
            }

            case Chat.create_message(message_params) do
              {:ok, _message} ->
                {:noreply,
                 socket
                 |> assign(:current_message, "")
                 |> assign(:uploading, false)}

              {:error, _changeset} ->
                {:noreply,
                 socket
                 |> put_flash(:error, "ไม่พามารถส่งข้อความได้")
                 |> assign(:uploading, false)}
            end

          {_, failed} ->
            error_messages = Enum.map(failed, fn {:error, reason} ->
              "การอัพโหลดล้มเหลว: #{inspect(reason)}"
            end)
            {:noreply,
             socket
             |> put_flash(:error, Enum.join(error_messages, ", "))
             |> assign(:uploading, false)}
        end

      # กรณีมีข้อความ
      byte_size(message) > 0 ->
        case Chat.create_message(%{
          content: message,
          user_name: socket.assigns.current_user,
          room_id: socket.assigns.room.id
        }) do
          {:ok, _message} ->
            {:noreply, assign(socket, :current_message, "")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "ไม่สามารถส่งข้อความได้")}
        end

      true ->
        {:noreply, socket}
    end
  end

  defp format_block_time(seconds) do
    now = NaiveDateTime.local_now()
    block_until = NaiveDateTime.add(now, seconds, :second)
    "คุณถูกแบนจนถึกเวลา #{Calendar.strftime(block_until, "%H:%M")}"
  end

  defp get_client_ip(socket) do
    connect_info = get_connect_info(socket, :x_headers)

    # ่ม logging เพื่อตรวจสอบ headers
    IO.inspect(connect_info, label: "Connection Headers")

    ip = cond do
      # ตรรวจสอบ ngrok header ก่่อน
      ngrok_ip = get_ngrok_ip(connect_info) ->
        IO.puts("Using Ngrok IP: #{ngrok_ip}")
        ngrok_ip

      # ถ้าไม่มี ngrok ให้ใช้ x-forwarded-for
      x_forwarded_for = get_forwarded_for(connect_info) ->
        IO.puts("Using X-Forwarded-For: #{x_forwarded_for}")
        x_forwarded_for

      # ้าไม่มี x-forwarded-for ให้ใช้ x-real-ip
      x_real_ip = get_real_ip(connect_info) ->
        IO.puts("Using X-Real-IP: #{x_real_ip}")
        x_real_ip

      # ถ้ามี header ใดๆ ให้ใช้ IP จก peer_data
      peer_data = get_connect_info(socket, :peer_data) ->
        ip = case peer_data do
          %{address: {127, 0, 0, 1}} -> "localhost"
          %{address: address} -> address |> :inet.ntoa() |> to_string()
          _ -> "unknown"
        end
        IO.puts("Using Peer Data IP: #{ip}")
        ip

      true ->
        IO.puts("No IP found, using unknown")
        "unknown"
    end

    # รววจสอบว่า IP ที่ไดไมช่ค่ว่าเหรือ nil
    case ip do
      nil -> "unknown"
      "" -> "unknown"
      ip when is_binary(ip) -> ip
      _ -> "unknown"
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
      String.starts_with?(content_type, "audio/") -> "audio"
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
    if is_nil(params.content) || String.trim(params.content) == "" do
      Map.delete(params, :content)
    else
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
     |> put_flash(:error, "ไม่พรอมอัพพโหลดไฟล์ห๗ี่อัพโหลด")
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

  # แยกการจัดการข้อควาออกมา
  defp handle_message_submit(message, socket) do
    case socket.assigns.uploads.media.entries do
      [] ->
        # ส่งข้อความปกติ
        case Chat.create_message(%{
          content: message,
          user_name: socket.assigns.current_user,
          room_id: socket.assigns.room.id
        }) do
          {:ok, _message} -> {:ok, socket |> assign(:current_message, "")}
          {:error, _} -> {:error, "ไม่สามารถส่งข้อคความได้", socket}
        end

      [entry] ->
        # ส่งรูปภาพหรือวิดีโอ
        if entry.done? do
          consume_uploaded_entries(socket, :media, fn meta, entry ->
            ext = Path.extname(entry.client_name)
            filename = "#{System.system_time()}-#{:crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)}#{ext}"

            case ExamplePhoenix.Uploads.upload_file(%{
              path: meta.path,
              filename: filename,
              content_type: entry.client_type
            }) do
              {:ok, url} ->
                message_params = %{
                  content: if(message == "", do: nil, else: message),
                  user_name: socket.assigns.current_user,
                  room_id: socket.assigns.room.id,
                  media_url: url,
                  media_type: get_media_type(entry.client_type),
                  content_type: entry.client_type
                }

                case Chat.create_message(message_params) do
                  {:ok, _message} -> {:ok, socket}
                  {:error, _} -> {:error, "Failed to save message"}
                end

              {:error, reason} ->
                Logger.error("Upload failed: #{inspect(reason)}")
                {:error, "Failed to upload file"}
            end
          end)
          |> case do
            [{:ok, socket}] ->
              {:ok, socket |> assign(:uploading, false) |> assign(:current_message, "")}
            [{:error, reason}] ->
              {:error, reason, socket}
            _ ->
              {:error, "Upload failed", socket}
          end
        else
          {:error, "Upload not complete", socket}
        end

      _ ->
        {:error, "Too many files", socket}
    end
  end

  # ปรับปรุงฟังก์ชัน handle_uploaded_file
  defp handle_uploaded_file(path, entry) do
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

  # ปรับบปรุงฟังก์ชัน create_media_message
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
  defp handle_upload_error(socket, error_message) do
    {:noreply,
     socket
     |> put_flash(:error, "ไกิดข้อผิดพลาด: #{error_message}")
     |> assign(:uploading, false)}
  end

  # สร้งข้อความปกติ
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

  # เพิ่ม error handling สำหรับ upload
  defp handle_upload_error(socket, :too_large) do
    {:noreply,
     socket
     |> put_flash(:error, "ไมล์มีขนาใหญ่เกินไป (สูงสุด 20MB)")
     |> assign(:uploading, false)}
  end

  defp handle_upload_error(socket, :too_many_files) do
    {:noreply,
     socket
     |> put_flash(:error, "สามารถอัพโหลดได้ครั้งละ 1 ไฟล์เท่านั้น")
     |> assign(:uploading, false)}
  end

  defp handle_upload_error(socket, _) do
    {:noreply,
     socket
     |> put_flash(:error, "ไกิดข้อผิดพลาดลาดในการอัพโหลด กรุณาลองใหม่อีกครั้ง")
     |> assign(:uploading, false)}
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
     |> assign(:current_gallery_index, 0)}
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

  @impl true
  def handle_event("close_gallery", _, socket) do
    {:noreply, assign(socket,
      show_gallery: false,
      current_image: nil
    )}
  end
end
