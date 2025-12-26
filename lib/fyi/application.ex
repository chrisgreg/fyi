defmodule FYI.Application do
  @moduledoc """
  FYI Application supervisor.

  Starts the Task.Supervisor used for async event delivery.

  Add this to your application's supervision tree or configure FYI
  to start automatically:

      # In your application.ex
      children = [
        # ... your other children
        FYI.Application
      ]

  Or let the installer add it for you with `mix fyi.install`.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: FYI.TaskSupervisor}
    ]

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
end
