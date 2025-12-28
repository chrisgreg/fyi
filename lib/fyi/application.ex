defmodule FYI.Application do
  @moduledoc """
  FYI Application supervisor.

  Starts the Task.Supervisor for fire-and-forget delivery, and optionally
  starts QueueWorker processes for durable queue-based delivery.

  Add this to your application's supervision tree or configure FYI
  to start automatically:

      # In your application.ex
      children = [
        # ... your other children
        FYI.Application
      ]

  Or let the installer add it for you with `mix fyi.install`.

  ## Queue Workers

  When `queue_enabled: true` is configured, multiple QueueWorker processes
  will be started to process jobs concurrently. The number of workers is
  controlled by the `queue_workers` config (default: 2).
  """

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        {Task.Supervisor, name: FYI.TaskSupervisor}
      ] ++ queue_workers()

    opts = [strategy: :one_for_one, name: FYI.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Returns the child spec for adding FYI to a supervision tree.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start, [:normal, opts]},
      type: :supervisor
    }
  end

  # Returns worker specs if queue is enabled
  defp queue_workers do
    if FYI.Config.queue_enabled?() do
      worker_count = FYI.Config.queue_workers()
      poll_interval = FYI.Config.queue_poll_interval()

      for i <- 1..worker_count do
        Supervisor.child_spec(
          {FYI.QueueWorker, [name: :"fyi_queue_worker_#{i}", poll_interval: poll_interval]},
          id: :"fyi_queue_worker_#{i}"
        )
      end
    else
      []
    end
  end
end
