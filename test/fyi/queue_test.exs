defmodule FYI.QueueTest do
  use ExUnit.Case, async: false

  alias FYI.Queue
  alias FYI.Schema.Job

  describe "Job schema" do
    test "new/4 creates a valid job changeset" do
      changeset = Job.new(
        "event-123",
        FYI.Sink.SlackWebhook,
        %{url: "https://hooks.slack.com/..."},
        %{name: "purchase.created", payload: %{amount: 100}}
      )

      assert changeset.valid?
      assert changeset.changes.event_id == "event-123"
      assert changeset.changes.sink_module == "Elixir.FYI.Sink.SlackWebhook"
      assert changeset.changes.state == :pending
      assert changeset.changes.attempts == 0
      assert changeset.changes.max_attempts == 10
    end

    test "mark_processing/1 increments attempts" do
      job = %Job{attempts: 0, state: :pending}
      changeset = Job.mark_processing(job)

      assert changeset.changes.state == :processing
      assert changeset.changes.attempts == 1
      assert changeset.changes[:attempted_at]
    end

    test "mark_completed/1 sets state and timestamp" do
      job = %Job{state: :processing}
      changeset = Job.mark_completed(job)

      assert changeset.changes.state == :completed
      assert changeset.changes[:completed_at]
    end

    test "mark_failed/2 schedules retry with backoff" do
      job = %Job{state: :processing, attempts: 1, max_attempts: 10, errors: []}
      changeset = Job.mark_failed(job, "Connection timeout")

      assert changeset.changes.state == :pending
      assert changeset.changes.last_error == "Connection timeout"
      assert length(changeset.changes.errors) == 1
      assert changeset.changes[:scheduled_at]
    end

    test "mark_failed/2 sets state to failed when max_attempts reached" do
      job = %Job{state: :processing, attempts: 10, max_attempts: 10, errors: []}
      changeset = Job.mark_failed(job, "Final attempt failed")

      assert changeset.changes.state == :failed
      assert changeset.changes.last_error == "Final attempt failed"
    end
  end

  describe "Config helpers" do
    test "queue_enabled?/0 returns false by default" do
      original = Application.get_env(:fyi, :queue_enabled)
      Application.delete_env(:fyi, :queue_enabled)

      assert FYI.Config.queue_enabled?() == false

      # Restore
      if original, do: Application.put_env(:fyi, :queue_enabled, original)
    end

    test "queue_enabled?/0 returns configured value" do
      original = Application.get_env(:fyi, :queue_enabled)
      Application.put_env(:fyi, :queue_enabled, true)

      assert FYI.Config.queue_enabled?() == true

      # Restore
      if original do
        Application.put_env(:fyi, :queue_enabled, original)
      else
        Application.delete_env(:fyi, :queue_enabled)
      end
    end

    test "queue_workers/0 returns default of 2" do
      original = Application.get_env(:fyi, :queue_workers)
      Application.delete_env(:fyi, :queue_workers)

      assert FYI.Config.queue_workers() == 2

      # Restore
      if original, do: Application.put_env(:fyi, :queue_workers, original)
    end

    test "queue_poll_interval/0 returns default of 1000ms" do
      original = Application.get_env(:fyi, :queue_poll_interval)
      Application.delete_env(:fyi, :queue_poll_interval)

      assert FYI.Config.queue_poll_interval() == 1000

      # Restore
      if original, do: Application.put_env(:fyi, :queue_poll_interval, original)
    end
  end

  # Note: Database-dependent tests would require test database setup
  # These are omitted for now but would include:
  # - enqueue/4
  # - fetch_next/0
  # - mark_completed/1
  # - mark_failed/2
  # - stats/0
  # - list_failed/1
  # - retry_job/1
  # - delete_completed_jobs/1
end
