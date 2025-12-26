defmodule FYI.Multi do
  @moduledoc """
  Integrates FYI events with Ecto.Multi for transactional event emission.

  This ensures events are only emitted after the transaction commits successfully.

  ## Example

      Ecto.Multi.new()
      |> Ecto.Multi.insert(:purchase, changeset)
      |> FYI.Multi.emit("purchase.created", fn %{purchase: p} ->
        %{payload: %{amount: p.amount, currency: p.currency}, actor: p.user_id}
      end)
      |> Repo.transaction()

  The event will only be emitted if the entire transaction succeeds.
  """

  alias Ecto.Multi

  @doc """
  Adds an FYI event emission to an Ecto.Multi.

  The callback receives the Multi changes map and should return a map with:
  - `:payload` - event payload (required)
  - `:actor` - who triggered the event (optional)
  - `:tags` - additional metadata (optional)
  - `:source` - event source (optional)

  ## Examples

      Multi.new()
      |> Multi.insert(:user, user_changeset)
      |> FYI.Multi.emit("user.created", fn %{user: user} ->
        %{payload: %{email: user.email}, actor: user.id}
      end)

      # With static payload
      Multi.new()
      |> Multi.update(:settings, settings_changeset)
      |> FYI.Multi.emit("settings.updated", fn _ ->
        %{payload: %{}, actor: current_user_id}
      end)
  """
  @spec emit(Multi.t(), String.t(), (map() -> map())) :: Multi.t()
  def emit(%Multi{} = multi, event_name, callback)
      when is_binary(event_name) and is_function(callback, 1) do
    operation_name = :"fyi_event_#{event_name}"

    Multi.run(multi, operation_name, fn _repo, changes ->
      result = callback.(changes)

      payload = Map.get(result, :payload, %{})

      opts =
        result
        |> Map.take([:actor, :tags, :source])
        |> Keyword.new()

      FYI.emit(event_name, payload, opts)
    end)
  end

  @doc """
  Adds an FYI event emission with a static payload.

  ## Examples

      Multi.new()
      |> Multi.delete(:subscription, subscription)
      |> FYI.Multi.emit("subscription.cancelled", %{reason: "user_requested"}, actor: user_id)
  """
  @spec emit(Multi.t(), String.t(), map(), keyword()) :: Multi.t()
  def emit(%Multi{} = multi, event_name, payload, opts \\ [])
      when is_binary(event_name) and is_map(payload) do
    operation_name = :"fyi_event_#{event_name}"

    Multi.run(multi, operation_name, fn _repo, _changes ->
      FYI.emit(event_name, payload, opts)
    end)
  end
end
