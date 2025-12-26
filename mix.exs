defmodule FYI.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/yourusername/fyi"

  def project do
    [
      app: :fyi,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      name: "FYI",
      description: "In-app events & feedback with Slack/Telegram notifications",
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:igniter, "~> 0.5"},

      # Optional Phoenix dependencies
      {:ecto_sql, "~> 3.10", optional: true},
      {:phoenix_live_view, "~> 1.0", optional: true},
      {:phoenix_ecto, "~> 4.4", optional: true},

      # Dev/Test
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Your Name"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end
end
