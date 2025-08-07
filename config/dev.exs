
import Config

config :reoxt, Reoxt.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "reoxt_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :reoxt, ReoxtWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 5000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "your-secret-key-base-here-change-in-production",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:reoxt, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:reoxt, ~w(--watch)]}
  ]

config :reoxt, ReoxtWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/reoxt_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :reoxt, dev_routes: true

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime
