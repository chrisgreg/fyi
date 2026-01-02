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

## Configuration

```elixir
# config/config.exs
config :fyi,
  app_name: "MyApp",
  persist_events: true,
  repo: MyApp.Repo,
  prefix: "fyi", # optional
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

FYI is intentionally simple:

- ❌ No Oban
- ❌ No durable queues or persistent job storage
- ✅ Fire-and-forget async delivery with automatic retries
- ✅ Phoenix + Ecto assumed
- ✅ Failures are logged, never block your application

Think "Oban Pro install experience", but for events + feedback.

### HTTP Retries

FYI automatically retries failed HTTP requests to sinks using exponential backoff:

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

## Development

To use FYI locally without publishing to Hex:

```elixir
# In your app's mix.exs
{:fyi, path: "../fyi"}
```

## License

MIT
