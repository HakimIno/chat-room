# lib/example_phoenix_web/live/room_live/show.ex
defmodule ExamplePhoenixWeb.ChatLive.Show do
  use ExamplePhoenixWeb, :live_view
  alias ExamplePhoenix.{Chat, Accounts.RateLimit}
  import Phoenix.Component
  import Phoenix.HTML.Link  # This adds the link/2 function

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

  @impl true
  def mount(%{"id" => room_id}, session, socket) do
    case Chat.get_room!(room_id) do
      %Chat.Room{} = room ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(ExamplePhoenix.PubSub, "room:#{room_id}")
        end

        # โหลดข้อความเก่าและเรียงตาม inserted_at
        messages =
          room_id
          |> Chat.list_messages()
          |> Enum.sort_by(&(&1.inserted_at), :asc)

        client_ip = get_client_ip(socket)

        {:ok,
         socket
         |> assign(:current_user, session["user_name"])
         |> assign(:room, room)
         |> assign(:messages, [])
         |> assign(:message_ids, MapSet.new())
         |> assign(:current_message, "")
         |> assign(:blocked, false)
         |> assign(:block_remaining_seconds, 0)
         |> assign(:show_emoji_modal, false)
         |> assign(:client_ip, client_ip)
         |> assign(:emojis, @emojis)
         |> stream(:messages, messages)}
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
    {:noreply, assign(socket, :current_message, message || "")}
  end

  @impl true
  def handle_event("handle_keydown", %{"key" => "Enter", "shiftKey" => false}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("handle_keyup", %{"key" => "Enter", "shiftKey" => false}, socket) do
    handle_send_message(socket)
  end

  @impl true
  def handle_event("submit_message", %{"message" => message}, socket) when byte_size(message) > 0 do
    if socket.assigns.blocked do
      {:noreply,
       socket
       |> put_flash(:error, format_block_time(socket.assigns.block_remaining_seconds))}
    else
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

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "ไม่สามารถส่งข้อความได้")}
      end
    end
  end

  @impl true
  def handle_event("submit_message", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_emoji_modal", _params, socket) do
    {:noreply, assign(socket, :show_emoji_modal, true)}
  end

  @impl true
  def handle_event("close_emoji_modal", _params, socket) do
    {:noreply, assign(socket, :show_emoji_modal, false)}
  end

  @impl true
  def handle_event("select_emoji", %{"emoji" => emoji}, socket) do
    current_message = socket.assigns.current_message || ""
    {:noreply, assign(socket, :current_message, current_message <> emoji)}
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
     |> assign(:current_message, current_message <> emoji)
     |> assign(:show_emoji_modal, false)}  # ปิด modal หลังจากเลือก emoji
  end

  defp handle_send_message(socket) do
    case socket.assigns.current_message do
      message when byte_size(message) > 0 ->
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
      _ ->
        {:noreply, socket}
    end
  end

  defp format_block_time(seconds) do
    now = NaiveDateTime.local_now()
    block_until = NaiveDateTime.add(now, seconds, :second)
    "คุณถูกแบนจนถึงเวลา #{Calendar.strftime(block_until, "%H:%M")}"
  end

  defp get_client_ip(socket) do
    connect_info = get_connect_info(socket, :x_headers)

    # ิ่ม logging เพื่อตรวจสอบ headers
    IO.inspect(connect_info, label: "Connection Headers")

    ip = cond do
      # ตรวจสอบ ngrok header ก่อน
      ngrok_ip = get_ngrok_ip(connect_info) ->
        IO.puts("Using Ngrok IP: #{ngrok_ip}")
        ngrok_ip

      # ถ้าไม่มี ngrok ให้ใช้ x-forwarded-for
      x_forwarded_for = get_forwarded_for(connect_info) ->
        IO.puts("Using X-Forwarded-For: #{x_forwarded_for}")
        x_forwarded_for

      # ถ้าไม่มี x-forwarded-for ให้ใช้ x-real-ip
      x_real_ip = get_real_ip(connect_info) ->
        IO.puts("Using X-Real-IP: #{x_real_ip}")
        x_real_ip

      # ถ้าไม่มี header ใดๆ ให้ใช้ IP จาก peer_data
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

    # ตรวจสอบว่า IP ที่ได้ไม่ช่ค่ว่างหรือ nil
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

  defp send_message(socket, message) do
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
  end

  defp format_message_time(datetime) do
    Calendar.strftime(datetime, "%H:%M")
  end
end
