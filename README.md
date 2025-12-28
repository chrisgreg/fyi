<h1 align="center">FYI</h1>

<p align="center">
  <a href="https://hex.pm/packages/fyi"><img src="https://img.shields.io/hexpm/v/fyi.svg" alt="Hex.pm"></a>
  <a href="https://hexdocs.pm/fyi"><img src="https://img.shields.io/badge/hex-docs-blue.svg" alt="Hex Docs"></a>
  <a href="https://hex.pm/packages/fyi"><img src="https://img.shields.io/hexpm/dt/fyi.svg" alt="Downloads"></a>
  <a href="https://github.com/chrisgreg/fyi/blob/main/LICENSE"><img src="https://img.shields.io/hexpm/l/fyi.svg" alt="License"></a>
</p>

<p align="center"><strong>Know what's happening in your app.</strong></p>

---

In-app events, user feedback, and instant Slack/Telegram notifications for Phoenix.

Stop refreshing your database to see if users are signing up. FYI gives you:

- 📤 **Event tracking** — Emit events from anywhere in your app with one line of code
- 📊 **Live dashboard** — Beautiful admin UI with search, filtering, and activity histograms
- 💬 **Feedback widget** — Drop-in component to collect user feedback (installs into your codebase)
- 🔔 **Instant notifications** — Get pinged in Slack or Telegram when important things happen
- 🎯 **Smart routing** — Send specific events to specific channels with glob patterns
- 🚀 **One-command setup** — `mix fyi.install` handles migrations, config, and routes

![FYI Admin Inbox](screenshot.png)

## Installation

Add `fyi` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:fyi, "~> 1.0.0"}
  ]
end
```

Then run the installer:

```bash
mix deps.get
mix fyi.install
```

This will:
1. Add `FYI.Application` to your supervision tree
2. Create a migration for the `fyi_events` table
3. Print instructions to add the `/fyi` route to your router
4. Add configuration stubs to your config files

### Installer Options

- `--no-ui` — Skip installing the admin inbox UI
- `--no-persist` — Skip the database migration (events won't be persisted)
- `--no-feedback` — Skip installing the feedback component
- `--queue` — Install the durable queue system for production deployments (see [Production Deployment](#production-deployment))

## Configuration

```elixir
# config/config.exs
config :fyi,
  app_name: "MyApp",
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
    %{match: "purchase.*", sinks: [:slack, :telegram]},
    %{match: "feedback.*", sinks: [:slack]}
  ]
```

### App Name

Set `app_name` to identify events when multiple apps share the same Slack channel or Telegram chat:

```elixir
config :fyi, app_name: "MyApp"
```

Messages will include the app name: `[MyApp] *purchase.created* by user_123`

### Emojis

Add emojis to your notifications in three ways (in priority order):

**1. Per-event override:**
```elixir
FYI.emit("error.critical", %{message: "DB down"}, emoji: "🚨")
```

**2. Pattern-based mapping:**
```elixir
config :fyi,
  emojis: %{
    "purchase.*" => "💰",
    "user.signup" => "👋",
    "feedback.*" => "💬",
    "error.*" => "🚨"
  }
```

**3. Default fallback:**
```elixir
config :fyi, emoji: "📣"
```

Messages will show as: `💰 [MyApp] *purchase.created* by user_123`

### Routing

Routes use simple glob matching:
- `purchase.*` matches `purchase.created`, `purchase.updated`, etc.
- `*` at the end matches any suffix

If no routes are configured, all events go to all sinks.

## Usage

### Emit an Event

```elixir
FYI.emit("purchase.created", %{amount: 4900, currency: "GBP"}, actor: user_id)

FYI.emit("user.signup", %{email: "user@example.com"}, source: "landing_page")

FYI.emit("error.critical", %{message: "DB connection failed"}, emoji: "🚨", tags: %{env: "prod"})
```

Options:
- `:actor` - who triggered the event (user_id, email, etc.)
- `:source` - where the event originated (e.g., "api", "web", "worker")
- `:tags` - additional metadata map for filtering
- `:emoji` - override emoji for this specific event

### Emit from Ecto.Multi (Recommended)

```elixir
Ecto.Multi.new()
|> Ecto.Multi.insert(:purchase, changeset)
|> FYI.Multi.emit("purchase.created", fn %{purchase: p} ->
  %{payload: %{amount: p.amount, currency: p.currency}, actor: p.user_id}
end)
|> Repo.transaction()
```

This ensures events are only emitted after the transaction commits successfully.

### Feedback Component

The installer creates a customizable feedback component in your codebase at `lib/your_app_web/components/fyi/feedback_component.ex`.

Use it in any LiveView:

```elixir
import MyAppWeb.FYI.FeedbackComponent

# In your template
<.feedback_button />
```

Customize as needed:

```heex
<.feedback_button
  title="Report an Issue"
  button_label="Report"
  button_icon="🐛"
  categories={[{"bug", "Bug"}, {"ux", "UX Problem"}, {"other", "Other"}]}
/>
```

Since the component lives in your codebase, you can freely modify the Tailwind classes, add fields, or change the behavior.

Skip installing with `mix fyi.install --no-feedback`.

### Admin Inbox

Add the route to your router (the installer prints this):

```elixir
# In router.ex
scope "/fyi", FYI.Web do
  pipe_through [:browser]
  live "/", InboxLive, :index
  live "/events/:id", InboxLive, :show
end
```

Visit `/fyi` to see the event inbox with:
- Activity histogram with time-based tooltips
- Real-time event updates (requires PubSub config)
- Time range filtering (5 minutes to all time)
- Event type filtering
- Search by event name or actor
- Event detail panel with full payload

### Real-time Updates

To enable real-time updates in the admin inbox, add your PubSub module:

```elixir
config :fyi, pubsub: MyApp.PubSub
```

New events will appear instantly without refreshing the page.

## Built-in Sinks

### Slack Webhook

```elixir
{FYI.Sink.SlackWebhook, %{
  url: "https://hooks.slack.com/services/...",
  username: "FYI Bot",      # optional
  icon_emoji: ":bell:"      # optional
}}
```

<details>
<summary>How to create a Slack webhook</summary>

1. Go to [api.slack.com/apps](https://api.slack.com/apps) and click **Create New App**
2. Choose **From scratch**, name it (e.g., "FYI"), and select your workspace
3. Click **Incoming Webhooks** in the sidebar, then toggle it **On**
4. Click **Add New Webhook to Workspace** and select the channel
5. Copy the webhook URL — it looks like `https://hooks.slack.com/services/T00/B00/xxxx`

</details>

### Telegram Bot

```elixir
{FYI.Sink.Telegram, %{
  token: "123456:ABC-DEF...",
  chat_id: "-1001234567890",
  parse_mode: "HTML"         # optional, default: "HTML"
}}
```

<details>
<summary>How to create a Telegram bot</summary>

1. Message [@BotFather](https://t.me/botfather) on Telegram
2. Send `/newbot` and follow the prompts to name your bot
3. Copy the **token** (looks like `123456789:ABCdefGHI...`)
4. Add the bot to your group/channel and send a message
5. Get your **chat_id** by visiting: `https://api.telegram.org/bot<TOKEN>/getUpdates`
   - Look for `"chat":{"id":-1001234567890}` in the response
   - Group IDs are negative numbers

</details>

## Custom Sinks

Implement the `FYI.Sink` behaviour:

```elixir
defmodule MyApp.DiscordSink do
  @behaviour FYI.Sink

  @impl true
  def id, do: :discord

  @impl true
  def init(config) do
    {:ok, %{webhook_url: config.url}}
  end

  @impl true
  def deliver(event, state) do
    # POST to Discord webhook using FYI.Client for automatic retries
    case FYI.Client.post(state.webhook_url, json: %{content: event.name}) do
      {:ok, %{status: s}} when s in 200..299 -> :ok
      {:ok, resp} -> {:error, resp}
      {:error, err} -> {:error, err}
    end
  end
end
```

Then add it to your config:

```elixir
sinks: [
  {MyApp.DiscordSink, %{url: "https://discord.com/api/webhooks/..."}}
]
```

## Design Philosophy

FYI is intentionally simple and gives you flexibility based on your needs:

**Development & Simple Use Cases:**
- ✅ Fire-and-forget async delivery with automatic retries
- ✅ Zero additional dependencies beyond Ecto
- ✅ Failures are logged, never block your application

**Production Deployments:**
- ✅ Optional durable queue using PostgreSQL SKIP LOCKED
- ✅ No Oban or external job queue needed
- ✅ Built-in retry logic with exponential backoff
- ✅ Job failure tracking and manual retry capability

Think "Oban Pro install experience", but for events + feedback.

### HTTP Retries (Fire-and-Forget Mode)

In fire-and-forget mode (default), FYI automatically retries failed HTTP requests using exponential backoff:

- **Default**: 3 retry attempts with delays of 1s, 2s, 4s
- **Retry conditions**: Network errors, 500-599 status codes
- **Respects**: `Retry-After` response headers

Configure retry behavior:

```elixir
# config/config.exs
config :fyi,
  http_client: [
    max_retries: 5,  # default: 3
    retry_delay: fn attempt -> attempt * 2000 end  # custom delay function
  ]
```

Set `max_retries: 0` to disable retries entirely.

## Production Deployment

For production workloads, enable the **durable queue system** to ensure reliable event delivery even during network failures or application restarts.

### Why Use the Queue?

**Fire-and-forget mode** (default) is simple but has limitations:
- Events can be lost if the app crashes during delivery
- Network failures beyond the 3-retry window lose events
- No visibility into failed deliveries

**Queue mode** gives you production-grade reliability:
- Jobs persisted to PostgreSQL before delivery
- Automatic retries with exponential backoff (up to 10 attempts over 16+ hours)
- Failed job tracking with error history
- Manual retry capability
- Zero external dependencies (uses PostgreSQL's SKIP LOCKED)

### Installation

Install with the `--queue` flag:

```bash
mix fyi.install --queue
```

Or add the migration manually for an existing installation:

```bash
# Generate timestamp manually or use the migration below
```

<details>
<summary>Manual migration for existing installations</summary>

Create `priv/repo/migrations/TIMESTAMP_create_fyi_jobs.exs`:

```elixir
defmodule MyApp.Repo.Migrations.CreateFyiJobs do
  use Ecto.Migration

  def change do
    create table(:fyi_jobs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_id, :string, null: false
      add :sink_module, :string, null: false
      add :sink_config, :map, default: %{}
      add :event_payload, :map, null: false

      # Job state
      add :state, :string, null: false, default: "pending"
      add :attempts, :integer, null: false, default: 0
      add :max_attempts, :integer, null: false, default: 10

      # Retry scheduling
      add :scheduled_at, :utc_datetime_usec, null: false
      add :attempted_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec

      # Error tracking
      add :last_error, :text
      add :errors, :jsonb, default: "[]"

      timestamps(type: :utc_datetime_usec)
    end

    # Index for efficient job fetching with SKIP LOCKED
    create index(:fyi_jobs, [:state, :scheduled_at])
    create index(:fyi_jobs, [:event_id])
    create index(:fyi_jobs, [:inserted_at])
  end
end
```

</details>

### Configuration

Enable the queue in your config:

```elixir
# config/config.exs (or config/prod.exs for production only)
config :fyi,
  queue_enabled: true,
  queue_workers: 4,          # Number of concurrent workers (default: 2)
  queue_poll_interval: 1000  # Poll interval in ms (default: 1000)
```

### How It Works

1. **Enqueue**: When you call `FYI.emit()`, the event is persisted to `fyi_jobs` table
2. **Poll**: Worker processes poll for pending jobs using PostgreSQL's `SKIP LOCKED`
3. **Process**: Each worker safely processes different jobs (no race conditions)
4. **Retry**: Failed jobs are automatically retried with exponential backoff:
   - Attempt 1: immediate
   - Attempt 2: 30 seconds
   - Attempt 3: 2 minutes
   - Attempt 4: 10 minutes
   - Attempts 5-10: 30 min, 1 hr, 2 hr, 4 hr, 8 hr, 16 hr
5. **Track**: Failed jobs are marked permanently failed after 10 attempts

### Monitoring Failed Jobs

Check queue stats programmatically:

```elixir
FYI.Queue.stats()
# => %{pending: 5, processing: 2, failed: 1, completed: 1234}

# List failed jobs
FYI.Queue.list_failed(limit: 50)

# Manually retry a failed job
FYI.Queue.retry_job(job_id)
```

### Cleanup

Completed jobs are kept for debugging. Clean them up periodically:

```elixir
# Delete completed jobs older than 7 days (recommended)
FYI.Queue.delete_completed_jobs(7)
```

Add this to a scheduled task (using `Oban.Cron`, `Quantum`, or similar):

```elixir
# Run daily at 3am
FYI.Queue.delete_completed_jobs(7)
```

### Worker Scaling

Adjust `queue_workers` based on your event volume:

- **Low volume** (< 100 events/hour): 1-2 workers
- **Medium volume** (100-1000 events/hour): 2-4 workers
- **High volume** (> 1000 events/hour): 4-8 workers

Workers automatically scale their polling:
- Poll fast (100ms) when jobs are available
- Poll slow (up to 5s) when queue is empty

### Best Practices

1. **Enable in production only**: Use fire-and-forget in dev for faster feedback
   ```elixir
   # config/prod.exs
   config :fyi, queue_enabled: true
   ```

2. **Monitor failed jobs**: Set up alerts for `FYI.Queue.stats().failed > 10`

3. **Clean up regularly**: Run `delete_completed_jobs/1` daily or weekly

4. **Database indexes**: The migration includes optimized indexes for SKIP LOCKED queries

## Development

To use FYI locally without publishing to Hex:

```elixir
# In your app's mix.exs
{:fyi, path: "../fyi"}
```

## License

MIT
