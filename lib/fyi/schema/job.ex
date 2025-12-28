defmodule FYI.Schema.Job do
  @moduledoc """
  Schema for queued jobs in the FYI system.

  Jobs are used for durable delivery of events to sinks (Slack, Telegram, etc).
  Uses PostgreSQL's SKIP LOCKED for safe concurrent processing.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime_usec]

  schema "fyi_jobs" do
    field :event_id, :string
    field :sink_module, :string
    field :sink_config, :map
    field :event_payload, :map

    # Job state
    field :state, Ecto.Enum, values: [:pending, :processing, :failed, :completed], default: :pending
    field :attempts, :integer, default: 0
    field :max_attempts, :integer, default: 10

    # Retry scheduling
    field :scheduled_at, :utc_datetime_usec
    field :attempted_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec

    # Error tracking
    field :last_error, :string
    field :errors, {:array, :map}, default: []

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Creates a new job for delivering an event to a sink.
  """
  def new(event_id, sink_module, sink_config, event_payload) do
    %__MODULE__{}
    |> cast(
      %{
        event_id: event_id,
        sink_module: to_string(sink_module),
        sink_config: sink_config,
        event_payload: event_payload,
        state: :pending,
        attempts: 0,
        max_attempts: 10,
        scheduled_at: DateTime.utc_now()
      },
      [:event_id, :sink_module, :sink_config, :event_payload, :state, :attempts, :max_attempts, :scheduled_at]
    )
    |> validate_required([:event_id, :sink_module, :event_payload])
  end

  @doc """
  Marks a job as processing.
  """
  def mark_processing(job) do
    job
    |> cast(
      %{
        state: :processing,
        attempted_at: DateTime.utc_now(),
        attempts: job.attempts + 1
      },
      [:state, :attempted_at, :attempts]
    )
  end

  @doc """
  Marks a job as completed.
  """
  def mark_completed(job) do
    job
    |> cast(
      %{
        state: :completed,
        completed_at: DateTime.utc_now()
      },
      [:state, :completed_at]
    )
  end

  @doc """
  Marks a job as failed and schedules retry with exponential backoff.

  Retry schedule:
  - Attempt 1: immediate
  - Attempt 2: 30 seconds
  - Attempt 3: 2 minutes
  - Attempt 4: 10 minutes
  - Attempt 5: 30 minutes
  - Attempt 6: 1 hour
  - Attempt 7: 2 hours
  - Attempt 8: 4 hours
  - Attempt 9: 8 hours
  - Attempt 10: 16 hours
  """
  def mark_failed(job, error_message) do
    next_attempt = job.attempts + 1

    # Calculate exponential backoff
    backoff_seconds = calculate_backoff(next_attempt)
    scheduled_at = DateTime.add(DateTime.utc_now(), backoff_seconds, :second)

    # Determine if we should retry
    state = if next_attempt >= job.max_attempts, do: :failed, else: :pending

    # Add error to history
    error_entry = %{
      attempt: job.attempts,
      error: error_message,
      timestamp: DateTime.utc_now()
    }
    errors = [error_entry | (job.errors || [])]

    job
    |> cast(
      %{
        state: state,
        last_error: error_message,
        errors: errors,
        scheduled_at: scheduled_at
      },
      [:state, :last_error, :errors, :scheduled_at]
    )
  end

  # Exponential backoff calculation
  # Returns delay in seconds before next retry
  defp calculate_backoff(attempt) when attempt <= 1, do: 0
  defp calculate_backoff(2), do: 30
  defp calculate_backoff(3), do: 120
  defp calculate_backoff(4), do: 600
  defp calculate_backoff(5), do: 1_800
  defp calculate_backoff(6), do: 3_600
  defp calculate_backoff(7), do: 7_200
  defp calculate_backoff(8), do: 14_400
  defp calculate_backoff(9), do: 28_800
  defp calculate_backoff(_), do: 57_600
end
