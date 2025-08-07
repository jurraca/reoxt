
import Config

config :reoxt,
  ecto_repos: [Reoxt.Repo],
  generators: [timestamp_type: :utc_datetime]

config :reoxt, ReoxtWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ReoxtWeb.ErrorHTML, json: ReoxtWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Reoxt.PubSub,
  live_view: [signing_salt: "your-signing-salt"]

config :reoxt, Reoxt.Mailer, adapter: Swoosh.Adapters.Local

config :esbuild,
  version: "0.17.11",
  reoxt: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.4.0",
  reoxt: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

# Bitcoin RPC configuration
config :reoxt,
  bitcoin_rpc_user: System.get_env("BITCOIN_RPC_USER", "bitcoinrpc"),
  bitcoin_rpc_password: System.get_env("BITCOIN_RPC_PASSWORD", "changeme")

import_config "#{config_env()}.exs"
