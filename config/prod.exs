import Config

config :minesweeper_backend, MinesweeperBackendWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

config :logger, level: :info
