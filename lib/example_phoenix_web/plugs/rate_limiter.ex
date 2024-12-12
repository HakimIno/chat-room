defmodule ExamplePhoenixWeb.Plugs.RateLimiter do
  import Plug.Conn
  
  def init(opts), do: opts

  def call(conn, _opts) do
    case check_rate(conn) do
      {:ok, _count} ->
        conn
      {:error, _limit} ->
        conn
        |> put_status(:too_many_requests)
        |> Phoenix.Controller.json(%{error: "Rate limit exceeded"})
        |> halt()
    end
  end

  defp check_rate(conn) do
    # Rate limit: 100 requests per minute per IP
    Hammer.check_rate(
      "#{get_ip(conn)}",  # rate limit key
      60_000,            # time window (1 minute in milliseconds)
      100                # max requests in window
    )
  end

  defp get_ip(conn) do
    conn.remote_ip
    |> :inet.ntoa()
    |> to_string()
  end
end
