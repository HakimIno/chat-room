defmodule ExamplePhoenixWeb.ChatLive.FormComponent do
  use ExamplePhoenixWeb, :live_component
  alias ExamplePhoenix.Chat

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black/50 backdrop-blur-sm z-50">
      <div class="fixed inset-0 z-20 overflow-y-auto">
        <div class="flex min-h-full items-center justify-center p-4">
          <div class="relative bg-white rounded-2xl shadow-2xl w-full max-w-md transform transition-all">
            <!-- Modal Header -->
            <div class="p-6 border-b border-gray-100">
              <div class="flex items-center justify-between">
                <h3 class="text-xl font-semibold text-gray-900"><%= @title %></h3>
                <button
                  phx-click="close_modal"
                  phx-target={@myself}
                  class="text-gray-400 hover:text-gray-500 transition-colors"
                >
                  <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M6 18L18 6M6 6l12 12"
                    />
                  </svg>
                </button>
              </div>
            </div>
            <!-- Modal Body -->
            <div class="p-6">
              <.form
                for={@form}
                id="room-form"
                phx-target={@myself}
                phx-change="validate"
                phx-submit="save"
                class="space-y-6"
              >
                <!-- Room Name Input -->
                <div>
                  <.label for={@form[:name].id}>ชื่อห้อง</.label>
                  <div class="mt-1">
                    <.input
                      field={@form[:name]}
                      type="text"
                      placeholder="ใส่ชื่อห้อง"
                      class="w-full rounded-lg border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                      required
                    />
                  </div>
                </div>
                <!-- Category Selection -->
                <div>
                  <.label for={@form[:category].id}>ประเภทห้อง</.label>
                  <div class="mt-1">
                    <.input
                      type="select"
                      field={@form[:category]}
                      options={[
                        [key: "เลือกประเภทห้อง", value: ""],
                        [key: "ทั่วไป", value: "general"],
                        [key: "เกม", value: "gaming"],
                        [key: "การศึกษา", value: "education"]
                      ]}
                      class="w-full rounded-lg border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                      required
                    />
                  </div>
                </div>
                <!-- Private Room Toggle -->
                <div class="flex items-center gap-3">
                  <div class="flex items-center">
                    <.input
                      field={@form[:is_private]}
                      type="checkbox"
                      phx-click="toggle_private"
                      phx-target={@myself}
                      class="h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
                    />
                    <span class="ml-2 block text-sm text-gray-900">
                      ห้องส่วนตัว
                    </span>
                  </div>
                </div>
                <!-- Password Input (Conditional) -->
                <div class={[
                  "transition-all duration-300",
                  !@show_password_field && "hidden"
                ]}>
                  <.label for={@form[:password].id}>รหัสผ่าน</.label>
                  <div class="mt-1 relative">
                    <.input
                      field={@form[:password]}
                      type="password"
                      placeholder="ใส่รหัสผ่านอย่างน้อย 4 ตัวอักษร"
                      required={@show_password_field}
                      minlength="4"
                      class="w-full rounded-lg border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 pr-10"
                    />
                    <div class="absolute inset-y-0 right-0 flex items-center pr-3">
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-5 w-5 text-gray-400"
                        viewBox="0 0 20 20"
                        fill="currentColor"
                      >
                        <path
                          fill-rule="evenodd"
                          d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z"
                          clip-rule="evenodd"
                        />
                      </svg>
                    </div>
                  </div>
                  <p class="mt-1 text-sm text-gray-500">
                    รหัสผ่านต้องมีความยาวอย่างน้อย 4 ตัวอักษร
                  </p>
                </div>
                <!-- Action Buttons -->
                <div class="flex items-center justify-end gap-3 mt-6 pt-6 border-t border-gray-100">
                  <.button
                    type="button"
                    phx-click="close_modal"
                    phx-target={@myself}
                    class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                  >
                    ยกเลิก
                  </.button>
                  <.button
                    type="submit"
                    class="px-4 py-2 text-sm font-medium text-white bg-gradient-to-r from-indigo-600 to-purple-600 rounded-lg hover:from-indigo-700 hover:to-purple-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                    phx-disable-with="กำลังสร้างห้อง..."
                  >
                    สร้างห้อง
                  </.button>
                </div>
              </.form>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def update(%{room: room} = assigns, socket) do
    changeset = Chat.change_room(room)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:show_password_field, room.is_private)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"room" => room_params}, socket) do
    changeset =
      socket.assigns.room
      |> Chat.change_room(room_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("toggle_private", _params, socket) do
    is_private = !socket.assigns.show_password_field

    changeset =
      socket.assigns.room
      |> Chat.change_room(%{is_private: is_private})

    {:noreply,
     socket
     |> assign(:show_password_field, is_private)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("save", %{"room" => room_params}, socket) do
    room_params = Map.put(room_params, "creator_id", socket.assigns.current_user)

    case Chat.create_room(room_params) do
      {:ok, _room} ->
        send(self(), {:close_modal, :created})
        {:noreply, socket}

      {:error, :rate_limited} ->
        remaining_time = Chat.get_remaining_time_for_block(socket.assigns.current_user)
        hours = div(remaining_time, 3600)
        minutes = div(rem(remaining_time, 3600), 60)

        {:noreply,
         socket
         |> put_flash(:error, "คุณสร้างห้องมากเกินไป กรุณารอ #{hours} ชั่วโมง #{minutes} นาที")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    send(self(), :close_modal)
    {:noreply, socket}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end
end
