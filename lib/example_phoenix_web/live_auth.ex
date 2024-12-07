defmodule ExamplePhoenixWeb.LiveAuth do
  import Phoenix.Component
  import Phoenix.LiveView

  def on_mount(:user_required, _params, session, socket) do
    IO.inspect(session, label: "LiveAuth Session")

    if user_name = session["user_name"] do
      {:cont, assign(socket, current_user: user_name)}
    else
      {:halt, redirect(socket, to: "/auth")}
    end
  end
end
