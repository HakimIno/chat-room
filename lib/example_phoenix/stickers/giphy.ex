defmodule ExamplePhoenix.Stickers.Giphy do
  @base_url "https://api.giphy.com/v1/stickers/trending"

  def get_trending_stickers do
    api_key = Application.get_env(:example_phoenix, :giphy)[:api_key]
    url = "#{@base_url}?api_key=#{api_key}&limit=8"

    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, parse_response(body)}

      {:ok, %HTTPoison.Response{status_code: 401}} ->
        {:error, "Invalid API key - Please check your GIPHY API key"}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "API request failed with status code: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp parse_response(body) do
    body
    |> Jason.decode!()
    |> Map.get("data")
    |> Enum.map(fn sticker ->
      %{
        id: sticker["id"],
        url: get_in(sticker, ["images", "fixed_height", "url"])
      }
    end)
  end
end
