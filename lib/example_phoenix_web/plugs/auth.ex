defmodule ExamplePhoenixWeb.Plugs.Auth do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if user_name = get_session(conn, :user_name) do
      IO.inspect(user_name, label: "Current User Name")

      conn
      |> assign(:current_user, user_name)
    else
      conn
      |> redirect(to: "/auth")
      |> halt()
    end
  end
end
