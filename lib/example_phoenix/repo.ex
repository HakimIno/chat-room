defmodule ExamplePhoenix.Repo do
  use Ecto.Repo,
    otp_app: :example_phoenix,
    adapter: Ecto.Adapters.Postgres
end
