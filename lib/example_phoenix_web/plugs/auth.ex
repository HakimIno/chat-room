defmodule ExamplePhoenixWeb.Plugs.Auth do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if user_name = get_session(conn, :user_name) do
      conn
      |> assign(:current_user, user_name)
      |> assign(:current_user_avatar, get_session(conn, :user_avatar))
    else
      conn
      |> redirect(to: "/auth")
      |> halt()
    end
  end
end
