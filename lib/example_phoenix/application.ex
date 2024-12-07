# lib/example_phoenix/application.ex
defmodule ExamplePhoenix.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ExamplePhoenixWeb.Telemetry,  # แก้การสะกดผิด
      ExamplePhoenix.Repo,
      {DNSCluster, query: Application.get_env(:example_phoenix, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ExamplePhoenix.PubSub},
      ExamplePhoenix.Presence,
      ExamplePhoenix.Chat.RoomRateLimit,
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
