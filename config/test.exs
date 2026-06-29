import Config

config :minesweeper_backend, :storage_driver, "memory"
config :minesweeper_backend, :room_empty_ttl_seconds, 0

config :minesweeper_backend, MinesweeperBackend.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "minesweeper_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :minesweeper_backend, MinesweeperBackendWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_test_secret_key_base_test_secret_key_base_test",
  server: false

config :minesweeper_backend, :redix,
  host: "localhost",
  port: 6379,
  database: 1

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime
