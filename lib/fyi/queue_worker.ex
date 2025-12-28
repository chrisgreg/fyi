defmodule FYI.QueueWorker do
  @moduledoc """
  GenServer that polls the job queue and processes jobs.

  Multiple workers can run concurrently - PostgreSQL's SKIP LOCKED
  ensures each worker gets different jobs with no race conditions.

  ## Configuration

      config :fyi,
        queue_enabled: true,
        queue_workers: 4,        # Number of concurrent workers
        queue_poll_interval: 1000 # Poll interval in ms

  Workers automatically scale based on load:
  - Poll faster when jobs are found
  - Poll slower when queue is empty
  """

  use GenServer
  require Logger
  alias FYI.Queue

  @default_poll_interval 1_000
  @fast_poll_interval 100
  @max_poll_interval 5_000

  # Client API

  @doc """
  Starts a queue worker.

  Options:
  - `:name` - Worker name (defaults to module name)
  - `:poll_interval` - Initial poll interval in ms (default: 1000)
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Triggers an immediate poll (useful for testing or forcing processing).
  """
  def poll(worker \\ __MODULE__) do
    GenServer.cast(worker, :poll)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    poll_interval = Keyword.get(opts, :poll_interval, @default_poll_interval)

    state = %{
      poll_interval: poll_interval,
      current_interval: poll_interval,
      processed_count: 0
    }

    # Start polling
    schedule_poll(state.current_interval)

    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    # Fetch and process next job
    case Queue.fetch_next() do
      nil ->
        # No jobs available - slow down polling
        new_interval = min(state.current_interval * 2, @max_poll_interval)
        schedule_poll(new_interval)
        {:noreply, %{state | current_interval: new_interval}}

      job ->
        # Process the job
        process_job(job)

        # Jobs available - speed up polling
        new_interval = @fast_poll_interval
        schedule_poll(new_interval)

        {:noreply, %{
          state |
          current_interval: new_interval,
          processed_count: state.processed_count + 1
        }}
    end
  end

  @impl true
  def handle_cast(:poll, state) do
    send(self(), :poll)
    {:noreply, state}
  end

  # Private Functions

  defp schedule_poll(interval) do
    Process.send_after(self(), :poll, interval)
  end

  defp process_job(job) do
    Logger.debug("Processing job #{job.id} (attempt #{job.attempts}/#{job.max_attempts})")

    try do
      # Reconstruct the sink module
      sink_module = String.to_existing_atom(job.sink_module)

      # Initialize sink
      sink = sink_module.init(job.sink_config)

      # Prepare the event
      event = %{
        id: job.event_id,
        payload: job.event_payload
      }

      # Deliver to sink
      case sink_module.deliver(sink, event) do
        :ok ->
          Logger.debug("Job #{job.id} completed successfully")
          Queue.mark_completed(job)

        {:error, reason} ->
          error_msg = "Delivery failed: #{inspect(reason)}"
          Logger.warning("Job #{job.id} failed: #{error_msg}")
          Queue.mark_failed(job, error_msg)
      end
    rescue
      error ->
        error_msg = Exception.format(:error, error, __STACKTRACE__)
        Logger.error("Job #{job.id} crashed: #{error_msg}")
        Queue.mark_failed(job, error_msg)
    end
  end
end
