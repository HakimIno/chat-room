defmodule ExamplePhoenixWeb.Router do
  use ExamplePhoenixWeb, :router

  @security_headers %{
    "content-security-policy" =>
      "default-src 'self' 'unsafe-inline' 'unsafe-eval' blob: data: https:; " <>
      "script-src 'self' 'unsafe-inline' 'unsafe-eval' https:; " <>
      "style-src 'self' 'unsafe-inline' https:; " <>
      "img-src 'self' blob: data: https: *; " <>
      "font-src 'self' data: https:; " <>
      "connect-src 'self' https: wss:; " <>
      "frame-src *; " <>
      "worker-src 'self' blob: https:; " <>
      "media-src 'self' blob: https:; " <>
      "object-src 'none'; " <>
      "base-uri 'self';",
    "permissions-policy" => "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()",
    "x-frame-options" => "ALLOWALL",
    "x-content-type-options" => "nosniff",
    "x-xss-protection" => "1; mode=block",
    "access-control-allow-origin" => "*",
    "access-control-allow-methods" => "GET, POST, PUT, DELETE, OPTIONS",
    "access-control-allow-headers" => "accept, content-type, authorization",
    "access-control-allow-credentials" => "true",
    "access-control-max-age" => "600"
  }

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ExamplePhoenixWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers, @security_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug ExamplePhoenixWeb.Plugs.RateLimiter
  end

  pipeline :auth do
    plug ExamplePhoenixWeb.Plugs.Auth
  end

  scope "/", ExamplePhoenixWeb do
    pipe_through :browser

    get "/", ChatController, :redirect_to_chat
    get "/auth", AuthController, :index
    post "/auth", AuthController, :create
    delete "/auth/logout", AuthController, :delete
  end

  scope "/", ExamplePhoenixWeb do
    pipe_through [:browser, :auth]

    live_session :authenticated,
      on_mount: [{ExamplePhoenixWeb.LiveAuth, :user_required}],
      session: {ExamplePhoenixWeb.Router, :get_session, []} do
      live "/chat", RoomLive.Index, :index
      live "/chat/:id", RoomLive.Show, :show
    end
  end

  def get_session(conn) do
    %{"user_name" => get_session(conn, :user_name)}
  end

  forward "/favicon-proxy", ExamplePhoenixWeb.FaviconProxy
end
