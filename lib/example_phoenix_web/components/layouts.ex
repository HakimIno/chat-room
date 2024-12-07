defmodule ExamplePhoenixWeb.Layouts do
  use ExamplePhoenixWeb, :html

  embed_templates "layouts/*"

  def app(assigns) do
    assigns =
      assign_new(assigns, :current_user, fn ->
        case assigns do
          %{current_user: current_user} -> current_user
          _ -> nil
        end
      end)

    ~H"""
    <header class="px-4 sm:px-6 lg:px-8">
      <div class="flex items-center justify-between border-b border-zinc-100 py-3">
        <div class="flex items-center gap-4">
          <a href="/" class="text-2xl font-bold">Chat App</a>
        </div>
        <%= if @current_user do %>
          <div class="flex items-center gap-4">
            <span>Welcome, <%= @current_user %></span>
            <.link href={~p"/auth/logout"} method="delete" class="text-red-600 hover:text-red-700">
              Logout
            </.link>
          </div>
        <% end %>
      </div>
    </header>
    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl">
        <.flash_group flash={@flash} />
        <%= @inner_content %>
      </div>
    </main>
    """
  end
end
