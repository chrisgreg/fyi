# FYI

In-app events & feedback with Slack/Telegram notifications for Phoenix.

FYI is a drop-in Elixir/Phoenix package that lets developers:

- 📤 **Emit events** from your app (waitlist signups, purchases, etc.)
- 💬 **Collect user feedback** via a simple in-app UI
- 🔔 **Get notified** in Slack and Telegram when things happen
- 🚀 **Install everything** with a single `mix fyi.install`

## Installation

Add `fyi` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:fyi, "~> 0.1.0"}
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
3. Add a `/fyi` route scope to your router
4. Add configuration stubs to your config files

### Installer Options

- `--no-ui` — Skip installing the Phoenix UI components
- `--no-persist` — Skip the database migration (events won't be persisted)

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

Messages will show as: `[MyApp] *purchase.created* by user_123`

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

FYI.emit("user.signup", %{email: "user@example.com"}, tags: %{source: "landing_page"})
```

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

Add the feedback button to your app layout:

```heex
<FYI.Web.FeedbackButton.fyi_feedback_button />
```

Or import and use as a function component:

```elixir
import FYI.Web.FeedbackButton

# In your template
<.fyi_feedback_button />
```

### Admin Inbox

Visit `/fyi` in your app to see the event inbox with:
- List of recent events
- Filtering by event name and actor
- Event detail view with payload

## Built-in Sinks

### Slack Webhook

```elixir
{FYI.Sink.SlackWebhook, %{
  url: "https://hooks.slack.com/services/...",
  username: "FYI Bot",      # optional
  icon_emoji: ":bell:"      # optional
}}
```

### Telegram Bot

```elixir
{FYI.Sink.Telegram, %{
  token: "123456:ABC-DEF...",
  chat_id: "-1001234567890",
  parse_mode: "HTML"         # optional, default: "HTML"
}}
```

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
    # POST to Discord webhook
    case Req.post(state.webhook_url, json: %{content: event.name}) do
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
- ❌ No durable queues, retries, or backoff
- ✅ Fire-and-forget HTTP notifications
- ✅ Phoenix + Ecto assumed
- ✅ Failures are logged, never block

Think "Oban Pro install experience", but for events + feedback.

## License

MIT
