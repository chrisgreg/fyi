defmodule FYI.Sink do
  @moduledoc """
  Behaviour for FYI notification sinks.

  A sink is a destination for events (Slack, Telegram, etc.).
  Implement this behaviour to create custom sinks.

  ## Example

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
          :ok
        end
      end
  """

  alias FYI.Event

  @doc """
  Returns the unique identifier for this sink.
  Used for routing configuration.
  """
  @callback id() :: atom()

  @doc """
  Initializes the sink with the given configuration.
  Called once before delivering events.
  """
  @callback init(config :: map()) :: {:ok, state :: term()} | {:error, term()}

  @doc """
  Delivers an event to the sink.
  Should return `:ok` on success or `{:error, reason}` on failure.
  """
  @callback deliver(event :: Event.t(), state :: term()) :: :ok | {:error, term()}
end
