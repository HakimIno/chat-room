defmodule ExamplePhoenix.Uploads do
  require Logger

  def upload_file(%{path: path, filename: filename, content_type: content_type}) do
    bucket = Application.get_env(:example_phoenix, :r2)[:bucket_name]
    public_url = Application.get_env(:example_phoenix, :r2)[:public_url]

    Logger.info("Starting file upload to R2")
    Logger.info("Bucket: #{bucket}")
    Logger.info("Filename: #{filename}")
    Logger.info("Content Type: #{content_type}")

    try do
      {:ok, content} = File.read(path)

      opts = [
        {:content_type, content_type},
        {:acl, :public_read},
        {:cache_control, "public, max-age=31536000"}
      ]

      result =
        ExAws.S3.put_object(bucket, filename, content, opts)
        |> ExAws.request()

      case result do
        {:ok, response} ->
          Logger.info("R2 Response: #{inspect(response)}")
          url = "#{public_url}/#{filename}"
          Logger.info("File uploaded successfully. URL: #{url}")
          {:ok, url}

        {:error, error} ->
          Logger.error("Upload failed with error: #{inspect(error)}")
          {:error, "Failed to upload file: #{inspect(error)}"}
      end
    rescue
      e ->
        Logger.error("Upload failed with exception: #{inspect(e)}")
        {:error, "Failed to upload file: #{inspect(e)}"}
    end
  end
end
