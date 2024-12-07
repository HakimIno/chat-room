defmodule ExamplePhoenixWeb.Router do
  use ExamplePhoenixWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {ExamplePhoenixWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :auth do
    plug ExamplePhoenixWeb.Plugs.Auth
  end

  scope "/", ExamplePhoenixWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/auth", AuthController, :index
    post "/auth", AuthController, :create
    delete "/auth/logout", AuthController, :delete
  end

  scope "/", ExamplePhoenixWeb do
    pipe_through [:browser, :auth]

    live_session :authenticated,
      on_mount: [{ExamplePhoenixWeb.LiveAuth, :user_required}],
      session: {ExamplePhoenixWeb.Router, :get_session, []} do
      live "/chat", ChatLive.Index, :index
      live "/chat/new", ChatLive.Index, :new
      live "/chat/:id", ChatLive.Show, :show
    end
  end

  def get_session(conn) do
    %{"user_name" => get_session(conn, :user_name)}
  end
end
