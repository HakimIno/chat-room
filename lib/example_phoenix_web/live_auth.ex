defmodule ExamplePhoenixWeb.LiveAuth do
  import Phoenix.Component
  import Phoenix.LiveView

  def on_mount(:user_required, _params, session, socket) do
    if user_name = session["user_name"] do
      {:cont,
       socket
       |> assign(:current_user, user_name)
       |> assign(:current_user_avatar, session["user_avatar"])}
    else
      {:halt, redirect(socket, to: "/auth")}
    end
  end
end
