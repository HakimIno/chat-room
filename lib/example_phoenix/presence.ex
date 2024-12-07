# lib/example_phoenix/presence.ex
defmodule ExamplePhoenix.Presence do
  use Phoenix.Presence,
    otp_app: :example_phoenix,
    pubsub_server: ExamplePhoenix.PubSub
end
