import Config

if System.get_env("PHX_SERVER") do
  config :minesweeper_backend, MinesweeperBackendWeb.Endpoint, server: true
end

session_ttl =
  System.get_env("SESSION_TTL_SECONDS", "86400")
  |> String.to_integer()

room_max_players =
  System.get_env("ROOM_MAX_PLAYERS", "2")
  |> String.to_integer()

config :minesweeper_backend,
  session_ttl_seconds: session_ttl,
  room_max_players: room_max_players

redis_url = System.get_env("REDIS_URL", "redis://localhost:6379")

config :minesweeper_backend, :redix, url: redis_url

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :minesweeper_backend, MinesweeperBackend.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :minesweeper_backend, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :minesweeper_backend, MinesweeperBackendWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base
end
