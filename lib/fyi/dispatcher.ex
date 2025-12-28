defmodule FYI.Dispatcher do
  @moduledoc """
  Dispatches events to configured sinks.

  ## Modes

  - **Fire-and-forget** (default): Uses `Task.Supervisor` for immediate delivery.
    Fast but events may be lost on failures or crashes.

  - **Queued** (production): Uses PostgreSQL-backed durable queue with retries.
    Reliable delivery with exponential backoff. Enable with `queue_enabled: true`.

  ## Configuration

      config :fyi,
        queue_enabled: true,  # Enable durable queue (default: false)
        queue_workers: 4      # Number of workers (default: 2)
  """

  require Logger

  alias FYI.Config
  alias FYI.Event
  alias FYI.Queue
  alias FYI.Router

  @task_supervisor FYI.TaskSupervisor

  @doc """
  Dispatches an event to all matching sinks.

  Behavior depends on configuration:
  - If `queue_enabled: true`: Jobs are enqueued to database for durable delivery
  - If `queue_enabled: false`: Jobs are delivered immediately in background tasks

  Returns immediately in both cases.
  """
  @spec dispatch(Event.t()) :: :ok
  def dispatch(%Event{} = event) do
    sink_ids = Router.route(event.name)
    sinks = get_sinks_by_ids(sink_ids)

    if Config.queue_enabled?() do
      # Enqueue for durable delivery
      enqueue_deliveries(sinks, event)
    else
      # Fire-and-forget delivery
      for {sink_mod, config} <- sinks do
        start_delivery_task(sink_mod, config, event)
      end
    end

    :ok
  end

  defp get_sinks_by_ids(sink_ids) do
    :fyi
    |> Application.get_env(:sinks, [])
    |> Enum.filter(fn {mod, _config} -> mod.id() in sink_ids end)
  end

  defp start_delivery_task(sink_mod, config, event) do
    Task.Supervisor.start_child(@task_supervisor, fn ->
      deliver_to_sink(sink_mod, config, event)
    end)
  end

  defp deliver_to_sink(sink_mod, config, event) do
    with {:ok, state} <- sink_mod.init(config) do
      case sink_mod.deliver(event, state) do
        :ok ->
          Logger.debug("FYI: Delivered #{event.name} to #{sink_mod.id()}")

        {:error, reason} ->
          Logger.warning(
            "FYI: Sink #{sink_mod.id()} failed to deliver #{event.name}: #{inspect(reason)}"
          )
      end
    else
      {:error, reason} ->
        Logger.warning("FYI: Sink #{sink_mod.id()} failed to initialize: #{inspect(reason)}")
    end
  end

  defp enqueue_deliveries(sinks, event) do
    for {sink_mod, config} <- sinks do
      event_payload = %{
        id: event.id,
        name: event.name,
        payload: event.payload,
        tags: event.tags,
        actor: event.actor,
        source: event.source,
        inserted_at: event.inserted_at
      }

      case Queue.enqueue(event.id, sink_mod, config, event_payload) do
        {:ok, _job} ->
          Logger.debug("FYI: Enqueued #{event.name} to #{sink_mod.id()}")

        {:error, reason} ->
          Logger.error("FYI: Failed to enqueue #{event.name} to #{sink_mod.id()}: #{inspect(reason)}")
      end
    end

    :ok
  end
end
