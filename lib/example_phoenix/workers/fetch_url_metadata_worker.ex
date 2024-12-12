defmodule ExamplePhoenix.Workers.FetchUrlMetadataWorker do
  use Oban.Worker

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"url" => url}}) do
    ExamplePhoenix.Chat.get_url_metadata(url)
    :ok
  end
end
