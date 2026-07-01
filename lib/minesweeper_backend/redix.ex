defmodule MinesweeperBackend.Redix do
  @moduledoc """
  Thin wrapper around a single `Redix` connection supervised in the app tree.

  Game state for active rooms is stored in Redis hashes under
  `room:<room_id>:game`.
  """

  @conn __MODULE__

  def child_spec(_opts) do
    {url_or_opts, extra} = build_args()

    %{
      id: @conn,
      start: {Redix, :start_link, [url_or_opts, extra]},
      type: :worker,
      restart: :permanent
    }
  end

  def command(cmd), do: Redix.command(@conn, cmd)
  def command!(cmd), do: Redix.command!(@conn, cmd)
  def pipeline(cmds), do: Redix.pipeline(@conn, cmds)

  defp build_args do
    cfg = Application.get_env(:minesweeper_backend, :redix, [])
    extra = [name: @conn, sync_connect: false]

    case Keyword.get(cfg, :url) do
      url when is_binary(url) and url != "" ->
        {url, extra}

      _ ->
        opts =
          extra
          |> Keyword.put(:host, Keyword.get(cfg, :host, "localhost"))
          |> Keyword.put(:port, Keyword.get(cfg, :port, 6379))
          |> maybe_put(:database, Keyword.get(cfg, :database))

        {opts, []}
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
