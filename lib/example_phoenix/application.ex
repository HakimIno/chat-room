# lib/example_phoenix/application.ex
defmodule ExamplePhoenix.Application do
  use Application

  @impl true
  def start(_type, _args) do
    # Load .env file if it exists
    if File.exists?(".env"), do: Dotenv.load()

    # สร้าง ETS tables
    :ets.new(:room_blocks, [:set, :public, :named_table])
    :ets.new(:room_attempts, [:set, :public, :named_table])

    children = [
      ExamplePhoenix.Repo,
      ExamplePhoenixWeb.Telemetry,
      {Phoenix.PubSub, name: ExamplePhoenix.PubSub},
      ExamplePhoenixWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ExamplePhoenix.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ExamplePhoenixWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
