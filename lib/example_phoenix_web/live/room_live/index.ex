# lib/example_phoenix_web/live/chat_live/index.ex
defmodule ExamplePhoenixWeb.ChatLive.Index do
  use ExamplePhoenixWeb, :live_view
  alias ExamplePhoenix.Chat
  alias ExamplePhoenix.Chat.Room

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:current_user, session["user_name"])
     |> assign(:rooms, Chat.list_rooms())
     |> assign(:show_room_modal, false)
     |> assign(:show_password_modal, false)
     |> assign(:selected_room_id, nil)
     |> assign(:room, %Room{})}
  end

  @impl true
  def handle_event("show_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:room, %Room{})
     |> assign(:show_room_modal, true)}
  end

  @impl true
  def handle_info(:close_modal, socket) do
    {:noreply,
     socket
     |> assign(:show_room_modal, false)}
  end

  @impl true
  def handle_info({:close_modal, :created}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "สร้างห้องสำเร็จ")
     |> assign(:show_room_modal, false)
     |> assign(:rooms, Chat.list_rooms())}
  end

  @impl true
  def handle_event("show_password_modal", %{"room-id" => room_id}, socket) do
    {:noreply,
     socket
     |> assign(:show_password_modal, true)
     |> assign(:selected_room_id, room_id)}
  end

  @impl true
  def handle_event("close_password_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_password_modal, false)
     |> assign(:selected_room_id, nil)}
  end

  @impl true
  def handle_event("join_private_room", %{"id" => room_id, "password" => password}, socket) do
    case Chat.join_room(room_id, password) do
      {:ok, _room} ->
        {:noreply,
         socket
         |> push_navigate(to: ~p"/chat/#{room_id}")}

      {:error, :invalid_password} ->
        {:noreply,
         socket
         |> put_flash(:error, "รหัสผ่านไม่ถูกต้อง")
         |> assign(:show_password_modal, true)}
    end
  end

  @impl true
  def handle_event("validate", %{"room" => room_params}, socket) do
    # Debug log
    IO.inspect(room_params, label: "Received room params")

    # แปลง is_private เป็น boolean
    room_params =
      Map.update(room_params, "is_private", false, fn
        "on" -> true
        true -> true
        "true" -> true
        _ -> false
      end)

    # Debug log หลังจากแปลง is_private
    IO.inspect(room_params, label: "After is_private conversion")

    # เพิ่ม creator_id
    room_params = Map.put(room_params, "creator_id", socket.assigns.current_user)

    case Chat.create_room(room_params) do
      {:ok, _room} ->
        {:noreply,
         socket
         |> put_flash(:info, "สร้างห้องสำเร็จ")
         |> assign(:show_room_modal, false)
         |> assign(:rooms, Chat.list_rooms())}

      {:error, %Ecto.Changeset{} = changeset} ->
        # Debug log สำหรับ error
        IO.inspect(changeset.errors, label: "Validation errors")

        {:noreply,
         socket
         |> put_flash(:error, error_to_string(changeset))
         |> assign(:show_room_modal, true)}
    end
  end

  @impl true
  def handle_event("save", %{"room" => room_params}, socket) do
    # Debug log
    IO.inspect(room_params, label: "Received room params")

    # แปลง is_private เป็น boolean
    room_params =
      Map.update(room_params, "is_private", false, fn
        "on" -> true
        true -> true
        "true" -> true
        _ -> false
      end)

    # Debug log หลังจากแปลง is_private
    IO.inspect(room_params, label: "After is_private conversion")

    # เพิ่ม creator_id
    room_params = Map.put(room_params, "creator_id", socket.assigns.current_user)

    case Chat.create_room(room_params) do
      {:ok, _room} ->
        {:noreply,
         socket
         |> put_flash(:info, "สร้างห้องสำเร็จ")
         |> assign(:show_room_modal, false)
         |> assign(:rooms, Chat.list_rooms())}

      {:error, %Ecto.Changeset{} = changeset} ->
        # Debug log สำหรับ error
        IO.inspect(changeset.errors, label: "Validation errors")

        {:noreply,
         socket
         |> put_flash(:error, error_to_string(changeset))
         |> assign(:show_room_modal, true)}
    end
  end

  defp error_to_string(changeset) do
    Enum.map(changeset.errors, fn
      {:password, {"can't be blank", _}} ->
        "กรุณาใส่รหัสผ่านสำหรับห้องส่วนตัว"

      {field, {msg, _}} ->
        "#{field} #{msg}"
    end)
    |> Enum.join(", ")
  end
end
