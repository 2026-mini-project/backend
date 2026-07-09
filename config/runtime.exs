import Config

if System.get_env("PHX_SERVER") do
  config :minesweeper_backend, MinesweeperBackendWeb.Endpoint, server: true
end

session_ttl =
  System.get_env("SESSION_TTL_SECONDS", "3600")
  |> String.to_integer()

room_max_players =
  System.get_env("ROOM_MAX_PLAYERS", "2")
  |> String.to_integer()

cors_allowed_origins =
  "CORS_ORIGINS"
  |> System.get_env("*")
  |> String.split(",", trim: true)
  |> Enum.map(&String.trim/1)

config :minesweeper_backend,
  session_ttl_seconds: session_ttl,
  room_max_players: room_max_players,
  cors_allowed_origins: cors_allowed_origins

if config_env() == :prod do
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
    secret_key_base: secret_key_base,
    check_origin: if(cors_allowed_origins == ["*"], do: false, else: cors_allowed_origins)
end
