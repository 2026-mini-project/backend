defmodule MinesweeperBackendWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :minesweeper_backend

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  plug MinesweeperBackendWeb.Plugs.CORS

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug MinesweeperBackendWeb.Plugs.WsUpgrade

  plug MinesweeperBackendWeb.Router
end
