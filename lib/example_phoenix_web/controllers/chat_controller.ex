defmodule ExamplePhoenixWeb.ChatController do
  use ExamplePhoenixWeb, :controller

  def redirect_to_chat(conn, _params) do
    redirect(conn, to: ~p"/chat")
  end
end
