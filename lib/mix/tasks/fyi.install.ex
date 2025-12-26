defmodule Mix.Tasks.Fyi.Install do
  @shortdoc "Installs FYI into your Phoenix application"
  @moduledoc """
  Installs FYI into your Phoenix application.

      $ mix fyi.install

  ## Options

  - `--no-ui` - Skip installing the Phoenix UI components
  - `--no-persist` - Skip the database migration (events won't be persisted)
  - `--no-feedback` - Skip installing the feedback component

  ## What This Does

  1. Adds FYI.Application to your supervision tree
  2. Creates a migration for the `fyi_events` table (unless --no-persist)
  3. Adds a `/fyi` route scope to your router (unless --no-ui)
  4. Installs a customizable feedback component (unless --no-feedback)
  5. Adds configuration stubs to your config files
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
        no_persist: :boolean,
        no_feedback: :boolean
      ],
      defaults: [
        no_ui: false,
        no_persist: false,
        no_feedback: false
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
    |> maybe_add_feedback_component(opts)
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

  defp maybe_add_feedback_component(igniter, opts) do
    if opts[:no_feedback] do
      igniter
    else
      web_module = Igniter.Libs.Phoenix.web_module(igniter)
      app_name = Igniter.Project.Application.app_name(igniter)

      # Read the template
      template_path = Application.app_dir(:fyi, "priv/templates/feedback_component.ex")

      content =
        if File.exists?(template_path) do
          template_path
          |> File.read!()
          |> EEx.eval_string(assigns: [web_module: inspect(web_module)])
        else
          # Fallback template if priv file not found (during development)
          generate_feedback_component(web_module)
        end

      # Determine the target path
      app_name_str = to_string(app_name)
      target_path = "lib/#{app_name_str}_web/components/fyi/feedback_component.ex"

      igniter
      |> Igniter.create_new_file(target_path, content)
      |> Igniter.add_notice("""
      Feedback component installed at: #{target_path}

      Usage in any LiveView:

          import #{inspect(web_module)}.FYI.FeedbackComponent
          <.feedback_button />

      Or with customization:

          <.feedback_button
            title="Report an Issue"
            button_label="Report"
            button_icon="🐛"
            categories={[{"bug", "Bug"}, {"ux", "UX Issue"}]}
          />
      """)
    end
  end

  defp generate_feedback_component(web_module) do
    """
    defmodule #{inspect(web_module)}.FYI.FeedbackComponent do
      @moduledoc \"\"\"
      Feedback component for collecting user feedback.
      Customize the styling, categories, and behavior as needed.
      \"\"\"

      use Phoenix.LiveComponent

      @default_categories [
        {"bug", "Bug Report"},
        {"feature", "Feature Request"},
        {"improvement", "Improvement"},
        {"other", "Other"}
      ]

      @impl true
      def mount(socket) do
        {:ok,
         socket
         |> assign(:show_modal, false)
         |> assign(:submitted, false)}
      end

      @impl true
      def update(assigns, socket) do
        socket =
          socket
          |> assign(assigns)
          |> assign_new(:button_label, fn -> "Feedback" end)
          |> assign_new(:button_icon, fn -> "💬" end)
          |> assign_new(:title, fn -> "Send Feedback" end)
          |> assign_new(:categories, fn -> @default_categories end)

        {:ok, socket}
      end

      @impl true
      def handle_event("open", _, socket) do
        {:noreply, assign(socket, :show_modal, true)}
      end

      @impl true
      def handle_event("close", _, socket) do
        {:noreply,
         socket
         |> assign(:show_modal, false)
         |> assign(:submitted, false)}
      end

      @impl true
      def handle_event("submit", %{"message" => message, "category" => category, "email" => email}, socket) do
        payload = %{message: message, category: category, email: email}
        actor = socket.assigns[:current_user_id] || socket.assigns[:user_id]
        FYI.emit("feedback.submitted", payload, actor: actor, tags: %{category: category})
        {:noreply, assign(socket, :submitted, true)}
      end

      @impl true
      def render(assigns) do
        ~H\"\"\"
        <div>
          <button
            type="button"
            class="fixed bottom-6 right-6 z-40 flex items-center gap-2 px-4 py-2.5
                   bg-blue-500 hover:bg-blue-600 text-white text-sm font-medium
                   rounded-lg shadow-md hover:shadow-lg
                   transition-all duration-200 cursor-pointer"
            phx-click="open"
            phx-target={@myself}
          >
            <span>{@button_icon}</span>
            <span>{@button_label}</span>
          </button>

          <div :if={@show_modal} class="fixed inset-0 z-50 flex items-center justify-center bg-gray-900/50">
            <div
              class="w-[90%] max-w-md bg-white rounded-lg shadow-xl border border-gray-200"
              phx-click-away="close"
              phx-target={@myself}
            >
              <div class="flex items-center justify-between px-5 py-4 border-b border-gray-200">
                <h2 class="text-base font-semibold text-gray-900">{@title}</h2>
                <button
                  type="button"
                  class="text-gray-400 hover:text-gray-600 text-xl leading-none"
                  phx-click="close"
                  phx-target={@myself}
                >
                  &times;
                </button>
              </div>

              <div :if={@submitted} class="p-10 text-center">
                <div class="text-4xl mb-3">✅</div>
                <h3 class="text-base font-semibold text-gray-900 mb-1">Thank you!</h3>
                <p class="text-sm text-gray-500">Your feedback has been received.</p>
              </div>

              <div :if={!@submitted} class="p-5">
                <form phx-submit="submit" phx-target={@myself} class="space-y-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-500 uppercase tracking-wide mb-1.5">Category</label>
                    <select name="category" class="w-full px-3 py-2 text-sm border border-gray-200 rounded-md bg-white
                                                    focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
                      <option value="">Select a category...</option>
                      <option :for={{value, label} <- @categories} value={value}>{label}</option>
                    </select>
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-500 uppercase tracking-wide mb-1.5">Message *</label>
                    <textarea name="message" required placeholder="Tell us what's on your mind..."
                      class="w-full px-3 py-2 text-sm border border-gray-200 rounded-md min-h-[100px] resize-y
                             focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"></textarea>
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-500 uppercase tracking-wide mb-1.5">Email (optional)</label>
                    <input type="email" name="email" placeholder="your@email.com"
                      class="w-full px-3 py-2 text-sm border border-gray-200 rounded-md
                             focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
                  </div>
                  <button type="submit"
                    class="w-full py-2.5 px-4 bg-blue-500 hover:bg-blue-600 text-white text-sm font-medium rounded-md transition-colors">
                    Send Feedback
                  </button>
                </form>
              </div>
            </div>
          </div>
        </div>
        \"\"\"
      end

      def feedback_button(assigns) do
        assigns =
          assigns
          |> assign_new(:id, fn -> "fyi-feedback" end)
          |> assign_new(:button_label, fn -> "Feedback" end)
          |> assign_new(:button_icon, fn -> "💬" end)
          |> assign_new(:title, fn -> "Send Feedback" end)
          |> assign_new(:categories, fn -> @default_categories end)

        ~H\"\"\"
        <.live_component
          module={__MODULE__}
          id={@id}
          button_label={@button_label}
          button_icon={@button_icon}
          title={@title}
          categories={@categories}
        />
        \"\"\"
      end
    end
    """
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
