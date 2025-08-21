# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :reoxt,
  ecto_repos: [Reoxt.Repo],
  generators: [timestamp_type: :utc_datetime]

config :gold, :localnode,
  hostname: System.get_env("RPC_HOST"),
  port: System.get_env("RPC_PORT") || 8332,
  user: System.get_env("RPC_USER"),
  password: System.get_env("RPC_PW")

# Configures the endpoint
config :reoxt, ReoxtWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ReoxtWeb.ErrorHTML, json: ReoxtWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Reoxt.PubSub,
  live_view: [signing_salt: "uhWodoqY"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  reoxt: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  reoxt: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
