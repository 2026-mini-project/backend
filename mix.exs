defmodule MinesweeperBackend.MixProject do
  use Mix.Project

  def project do
    [
      app: :minesweeper_backend,
      version: "0.1.0",
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {MinesweeperBackend.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7.14"},
      {:ecto, "~> 3.10"},
      {:jason, "~> 1.4"},
      {:redix, "~> 1.5"},
      {:phoenix_pubsub, "~> 2.1"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.1"},
      {:dns_cluster, "~> 0.1.3"},
      {:bandit, "~> 1.5"},
      {:open_api_spex, "~> 3.16"},
      {:plug, "~> 1.20", override: true}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      test: ["test"]
    ]
  end
end
