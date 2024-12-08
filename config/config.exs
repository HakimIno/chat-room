# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :example_phoenix,
  ecto_repos: [ExamplePhoenix.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :example_phoenix, ExamplePhoenixWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ExamplePhoenixWeb.ErrorHTML, json: ExamplePhoenixWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ExamplePhoenix.PubSub,
  live_view: [signing_salt: "4hw0InXi"],
  adapter: Phoenix.PubSub.PG2

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :example_phoenix, ExamplePhoenix.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  example_phoenix: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  example_phoenix: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
config :ex_aws,
  access_key_id: "522e5650436a033ffd13c065884753ff",
  secret_access_key: "446af8c0c1ebe72fe450a51aad53666fc26bf27ef93592ecd85cf5ae243745eb",
  region: "auto",
  s3: [
    scheme: "https://",
    host: "436b6a515d460c25108e569e4cc2ffdf.r2.cloudflarestorage.com",
    region: "auto",
    port: 443
  ]

# เพิ่มการตั้งค�า SSL
config :ex_aws, :hackney_opts,
  recv_timeout: 30_000,
  pool: false,
  ssl_options: [
    verify: :verify_none
  ]

config :example_phoenix, :r2,
  bucket_name: "lyra",
  public_url: "https://pub-11496457277242a8b2070cbd977c20ef.r2.dev"
