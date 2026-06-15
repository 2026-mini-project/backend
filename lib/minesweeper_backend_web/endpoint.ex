defmodule MinesweeperBackendWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :minesweeper_backend

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  plug MinesweeperBackendWeb.Router

  socket "/socket", MinesweeperBackendWeb.UserSocket,
    websocket: [
      connect_info: [:peer_data, :x_headers],
      timeout: :infinity
    ]
end
