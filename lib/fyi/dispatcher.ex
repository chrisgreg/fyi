defmodule FYI.Dispatcher do
  @moduledoc """
  Dispatches events to configured sinks asynchronously.

  Uses `Task.Supervisor` for fire-and-forget delivery.
  Failures are logged but don't affect the caller.
  """

  require Logger

  alias FYI.Event
  alias FYI.Router

  @task_supervisor FYI.TaskSupervisor

  @doc """
  Dispatches an event to all matching sinks asynchronously.
  Returns immediately; delivery happens in background tasks.
  """
  @spec dispatch(Event.t()) :: :ok
  def dispatch(%Event{} = event) do
    sink_ids = Router.route(event.name)
    sinks = get_sinks_by_ids(sink_ids)

    for {sink_mod, config} <- sinks do
      start_delivery_task(sink_mod, config, event)
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
end
