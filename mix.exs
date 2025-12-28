defmodule FYI.MixProject do
  use Mix.Project

  @version "1.0.2"
  @source_url "https://github.com/chrisgreg/fyi"

  def project do
    [
      app: :fyi,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),

      # Hex
      name: "FYI",
      description: "In-app events & feedback with Slack/Telegram notifications for Phoenix",
      package: package(),
      docs: docs(),
      source_url: @source_url,
      homepage_url: @source_url
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
      # HTTP client for sinks
      {:req, "~> 0.5"},

      # JSON encoding
      {:jason, "~> 1.4"},

      # Installer
      {:igniter, "~> 0.5"},

      # Phoenix (optional - for admin UI and feedback component)
      {:ecto_sql, "~> 3.10", optional: true},
      {:phoenix_live_view, "~> 1.0", optional: true},
      {:phoenix_ecto, "~> 4.4", optional: true},

      # PubSub for real-time updates (optional)
      {:phoenix_pubsub, "~> 2.1", optional: true},

      # Dev/Test
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:mimic, "~> 1.7", only: :test}
    ]
  end

  defp package do
    [
      maintainers: ["Chris Gregori"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      files: ~w(lib priv .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: "v#{@version}",
      formatters: ["html"]
    ]
  end
end
