defmodule FYI do
  @moduledoc """
  In-app events & feedback with Slack/Telegram notifications.

  FYI provides a simple way to:
  - Emit events from your app (waitlist signups, purchases, etc.)
  - Get notified in Slack and Telegram when things happen
  - Optionally persist events to the database

  ## Quick Start

      # Emit an event
      FYI.emit("purchase.created", %{amount: 4900, currency: "GBP"}, actor: user_id)

      # Emit from Ecto.Multi (recommended)
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:purchase, changeset)
      |> FYI.Multi.emit("purchase.created", fn %{purchase: p} ->
        %{payload: %{amount: p.amount}, actor: p.user_id}
      end)
      |> Repo.transaction()

  ## Configuration

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
  """

  alias FYI.Event
  alias FYI.Dispatcher

  @doc """
  Emits an event with the given name and payload.

  The event is:
  1. Optionally persisted to the database (if `persist_events: true`)
  2. Asynchronously sent to configured sinks

  ## Options

  - `:actor` - who triggered the event (user_id, email, etc.)
  - `:tags` - additional metadata map for filtering/routing
  - `:source` - where the event originated

  ## Examples

      FYI.emit("user.signup", %{email: "user@example.com"})

      FYI.emit("purchase.created", %{amount: 4900}, actor: user_id, tags: %{plan: "pro"})
  """
  @spec emit(String.t(), map(), keyword()) :: {:ok, Event.t()} | {:error, term()}
  def emit(name, payload \\ %{}, opts \\ []) do
    event = Event.new(name, payload, opts)

    with :ok <- maybe_persist(event),
         :ok <- Dispatcher.dispatch(event) do
      {:ok, event}
    end
  end

  @doc """
  Same as `emit/3` but raises on error.
  """
  @spec emit!(String.t(), map(), keyword()) :: Event.t()
  def emit!(name, payload \\ %{}, opts \\ []) do
    case emit(name, payload, opts) do
      {:ok, event} -> event
      {:error, reason} -> raise "FYI.emit! failed: #{inspect(reason)}"
    end
  end

  defp maybe_persist(event) do
    if persist_events?() do
      persist_event(event)
    else
      :ok
    end
  end

  defp persist_events? do
    Application.get_env(:fyi, :persist_events, false)
  end

  defp persist_event(event) do
    repo = Application.get_env(:fyi, :repo)

    if repo do
      attrs = %{
        id: event.id,
        name: event.name,
        payload: event.payload,
        actor: event.actor,
        tags: event.tags,
        source: event.source,
        inserted_at: event.occurred_at
      }

      case repo.insert(%FYI.Schema.Event{} |> struct(attrs)) do
        {:ok, _} -> :ok
        {:error, changeset} -> {:error, changeset}
      end
    else
      :ok
    end
  end
end
