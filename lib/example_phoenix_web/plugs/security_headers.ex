defmodule ExamplePhoenixWeb.Plugs.SecurityHeaders do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_security_headers()
  end

  defp put_security_headers(conn) do
    security_headers = %{
      # Content Security Policy
      "content-security-policy" => "default-src 'self'; " <>
        "script-src 'self' 'unsafe-inline' 'unsafe-eval'; " <>
        "style-src 'self' 'unsafe-inline'; " <>
        "img-src 'self' data: https:; " <>
        "connect-src 'self' wss:; " <>
        "font-src 'self';",
      
      # HTTP Strict Transport Security
      "strict-transport-security" => "max-age=31536000; includeSubDomains",
      
      # Prevent MIME type sniffing
      "x-content-type-options" => "nosniff",
      
      # Controls how the site appears in iframes
      "x-frame-options" => "SAMEORIGIN",
      
      # XSS Protection
      "x-xss-protection" => "1; mode=block",
      
      # Referrer Policy
      "referrer-policy" => "strict-origin-when-cross-origin",
      
      # Permissions Policy (formerly Feature-Policy)
      "permissions-policy" => "geolocation=(), microphone=(), camera=()"
    }

    Enum.reduce(security_headers, conn, fn {header, value}, conn ->
      put_resp_header(conn, header, value)
    end)
  end
end
