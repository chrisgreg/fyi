defmodule FYI.Queue do
  @moduledoc """
  Durable job queue using PostgreSQL's SKIP LOCKED for safe concurrent processing.

  This module provides a lightweight queue system without external dependencies.
  Uses Ecto and PostgreSQL's row-level locking to prevent race conditions.

  ## Features

  - **Durable**: Jobs persisted to database
  - **Concurrent**: SKIP LOCKED prevents workers from processing same job
  - **Exponential backoff**: Automatic retry with increasing delays
  - **Error tracking**: Complete error history per job
  - **Production-ready**: Battle-tested PostgreSQL features

  ## Usage

      # Enqueue a job
      Queue.enqueue(event_id, FYI.Sink.SlackWebhook, config, event_payload)

      # Fetch next available job (with SKIP LOCKED)
      Queue.fetch_next()

      # Mark job as completed
      Queue.mark_completed(job)

      # Mark job as failed (automatically schedules retry)
      Queue.mark_failed(job, "Connection timeout")
  """

  import Ecto.Query
  alias FYI.Schema.Job

  @doc """
  Enqueues a new job for delivery.

  Returns `{:ok, job}` or `{:error, changeset}`.
  """
  def enqueue(event_id, sink_module, sink_config, event_payload) do
    repo = FYI.Config.get(:repo)

    if repo do
      job = Job.new(event_id, sink_module, sink_config, event_payload)
      repo.insert(job)
    else
      {:error, :no_repo_configured}
    end
  end

  @doc """
  Fetches the next available job using SKIP LOCKED.

  This safely handles concurrent workers - each worker gets a different job.
  Jobs are locked in a transaction and marked as processing.

  Returns `{:ok, job}` or `nil` if no jobs available.
  """
  def fetch_next do
    repo = FYI.Config.get(:repo)

    if repo do
      repo.transaction(fn ->
        job =
          from(j in Job,
            where: j.state == :pending,
            where: j.scheduled_at <= ^DateTime.utc_now(),
            order_by: [asc: j.scheduled_at],
            limit: 1,
            lock: "FOR UPDATE SKIP LOCKED"
          )
          |> repo.one()

        case job do
          nil ->
            nil

          job ->
            job
            |> Job.mark_processing()
            |> repo.update!()
        end
      end)
      |> case do
        {:ok, result} -> result
        {:error, _} -> nil
      end
    else
      nil
    end
  end

  @doc """
  Marks a job as completed.

  Returns `{:ok, job}` or `{:error, changeset}`.
  """
  def mark_completed(job) do
    repo = FYI.Config.get(:repo)

    if repo do
      job
      |> Job.mark_completed()
      |> repo.update()
    else
      {:error, :no_repo_configured}
    end
  end

  @doc """
  Marks a job as failed and schedules retry with exponential backoff.

  If the job has exceeded max_attempts, it will be permanently failed.

  Returns `{:ok, job}` or `{:error, changeset}`.
  """
  def mark_failed(job, error_message) do
    repo = FYI.Config.get(:repo)

    if repo do
      job
      |> Job.mark_failed(error_message)
      |> repo.update()
    else
      {:error, :no_repo_configured}
    end
  end

  @doc """
  Returns statistics about the queue.

  Returns a map with:
  - `pending`: Number of pending jobs
  - `processing`: Number of jobs currently being processed
  - `failed`: Number of permanently failed jobs
  - `completed`: Number of completed jobs (last 24h)
  """
  def stats do
    repo = FYI.Config.get(:repo)

    if repo do
      yesterday = DateTime.add(DateTime.utc_now(), -24 * 3600, :second)

      %{
        pending: count_by_state(repo, :pending),
        processing: count_by_state(repo, :processing),
        failed: count_by_state(repo, :failed),
        completed: count_completed_since(repo, yesterday)
      }
    else
      %{pending: 0, processing: 0, failed: 0, completed: 0}
    end
  end

  @doc """
  Lists failed jobs for manual inspection or retry.

  Returns list of jobs ordered by most recent first.
  """
  def list_failed(opts \\ []) do
    repo = FYI.Config.get(:repo)
    limit = Keyword.get(opts, :limit, 100)

    if repo do
      from(j in Job,
        where: j.state == :failed,
        order_by: [desc: j.updated_at],
        limit: ^limit
      )
      |> repo.all()
    else
      []
    end
  end

  @doc """
  Manually retries a failed job by resetting it to pending.

  Useful for admin dashboards or manual intervention.
  """
  def retry_job(job_id) do
    repo = FYI.Config.get(:repo)

    if repo do
      from(j in Job, where: j.id == ^job_id)
      |> repo.one()
      |> case do
        nil ->
          {:error, :not_found}

        job ->
          job
          |> Ecto.Changeset.change(%{
            state: :pending,
            scheduled_at: DateTime.utc_now()
          })
          |> repo.update()
      end
    else
      {:error, :no_repo_configured}
    end
  end

  @doc """
  Deletes completed jobs older than the given number of days.

  Useful for cleanup tasks. Default is 7 days.
  """
  def delete_completed_jobs(days \\ 7) do
    repo = FYI.Config.get(:repo)

    if repo do
      cutoff = DateTime.add(DateTime.utc_now(), -days * 24 * 3600, :second)

      from(j in Job,
        where: j.state == :completed,
        where: j.completed_at < ^cutoff
      )
      |> repo.delete_all()
    else
      {0, nil}
    end
  end

  # Private helpers

  defp count_by_state(repo, state) do
    from(j in Job, where: j.state == ^state, select: count(j.id))
    |> repo.one()
    || 0
  end

  defp count_completed_since(repo, since) do
    from(j in Job,
      where: j.state == :completed,
      where: j.completed_at >= ^since,
      select: count(j.id)
    )
    |> repo.one()
    || 0
  end
end
