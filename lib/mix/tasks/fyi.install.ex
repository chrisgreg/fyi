defmodule Mix.Tasks.Fyi.Install do
  @shortdoc "Installs FYI into your Phoenix application"
  @moduledoc """
  Installs FYI into your Phoenix application.

      $ mix fyi.install

  ## Options

  - `--no-ui` - Skip installing the Phoenix UI components
  - `--no-persist` - Skip the database migration (events won't be persisted)

  ## What This Does

  1. Adds FYI.Application to your supervision tree
  2. Creates a migration for the `fyi_events` table (unless --no-persist)
  3. Adds a `/fyi` route scope to your router (unless --no-ui)
  4. Adds configuration stubs to your config files
  """

  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _parent) do
    %Igniter.Mix.Task.Info{
      group: :fyi,
      example: "mix fyi.install",
      positional: [],
      schema: [
        no_ui: :boolean,
        no_persist: :boolean
      ],
      defaults: [
        no_ui: false,
        no_persist: false
      ]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    opts = igniter.args.options

    igniter
    |> validate_phoenix_app()
    |> add_to_supervision_tree()
    |> maybe_add_migration(opts)
    |> maybe_add_routes(opts)
    |> add_config()
  end

  defp validate_phoenix_app(igniter) do
    # Check if Phoenix and Ecto are present
    case Igniter.Project.Deps.get_dep(igniter, :phoenix) do
      {:ok, _} ->
        igniter

      :error ->
        Igniter.add_warning(igniter, """
        FYI is designed for Phoenix applications. Some features may not work correctly
        without Phoenix and Ecto.
        """)
    end
  end

  defp add_to_supervision_tree(igniter) do
    Igniter.Project.Application.add_new_child(
      igniter,
      FYI.Application,
      after: [:repo, :pubsub, :endpoint]
    )
  end

  defp maybe_add_migration(igniter, opts) do
    if opts[:no_persist] do
      igniter
    else
      timestamp = Calendar.strftime(DateTime.utc_now(), "%Y%m%d%H%M%S")
      filename = "#{timestamp}_create_fyi_events.exs"

      migration_content = """
      defmodule Repo.Migrations.CreateFyiEvents do
        use Ecto.Migration

        def change do
          create table(:fyi_events, primary_key: false) do
            add :id, :string, primary_key: true
            add :name, :string, null: false
            add :payload, :map, default: %{}
            add :tags, :map, default: %{}
            add :actor, :string
            add :source, :string

            timestamps(updated_at: false, type: :utc_datetime_usec)
          end

          create index(:fyi_events, [:name])
          create index(:fyi_events, [:actor])
          create index(:fyi_events, [:inserted_at])
        end
      end
      """

      Igniter.create_new_file(igniter, "priv/repo/migrations/#{filename}", migration_content)
    end
  end

  defp maybe_add_routes(igniter, opts) do
    if opts[:no_ui] do
      igniter
    else
      route_code =
        """
        # FYI Admin UI
        scope "/fyi", FYI.Web do
          pipe_through [:browser]

          live "/", InboxLive, :index
          live "/events/:id", InboxLive, :show
        end
        """

      Igniter.add_notice(igniter, """
      Add the following to your router.ex inside the browser pipeline:

      #{route_code}
      """)
    end
  end

  defp add_config(igniter) do
    igniter
    |> Igniter.Project.Config.configure(
      "config.exs",
      :fyi,
      [:persist_events],
      true
    )
    |> Igniter.add_notice("""
    Configure FYI in your config/config.exs:

        config :fyi,
          persist_events: true,
          repo: MyApp.Repo,
          sinks: [
            {FYI.Sink.SlackWebhook, %{url: System.get_env("SLACK_WEBHOOK_URL")}},
            {FYI.Sink.Telegram, %{
              token: System.get_env("TELEGRAM_BOT_TOKEN"),
              chat_id: System.get_env("TELEGRAM_CHAT_ID")
            }}
          ],
          routes: [
            %{match: "waitlist.*", sinks: [:slack]},
            %{match: "purchase.*", sinks: [:slack, :telegram]}
          ]
    """)
  end
end
