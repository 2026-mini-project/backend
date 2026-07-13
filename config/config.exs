import Config

config :minesweeper_backend,
  generators: [timestamp_type: :utc_datetime, binary_id: true]

config :minesweeper_backend, MinesweeperBackendWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: MinesweeperBackendWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: MinesweeperBackend.PubSub

config :minesweeper_backend,
  session_ttl_seconds: 3_600,
  room_max_players: 2,
  cors_allowed_origins: ["*"],
  socket_identify_timeout_ms: 5_000,
  socket_ping_interval_ms: 10_000,
  socket_pong_timeout_ms: 3_000,
  game_board_size: 8,
  game_mine_count: 10

config :phoenix, :json_library, Jason

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

import_config "#{config_env()}.exs"
