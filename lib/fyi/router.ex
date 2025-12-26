defmodule FYI.Router do
  @moduledoc """
  Routes events to appropriate sinks based on configuration.

  Uses simple glob matching for event names:
  - `*` matches any sequence of characters within a segment
  - `**` is not supported (use `*` at the end)

  ## Example Configuration

      routes: [
        %{match: "waitlist.*", sinks: [:slack]},
        %{match: "purchase.*", sinks: [:slack, :telegram]},
        %{match: "feedback.*", sinks: [:slack]}
      ]

  If no routes are configured, all events go to all sinks.
  """

  @doc """
  Returns the list of sink IDs that should receive an event.
  """
  @spec route(String.t()) :: [atom()]
  def route(event_name) do
    routes = Application.get_env(:fyi, :routes)
    all_sink_ids = get_all_sink_ids()

    case routes do
      nil ->
        # No routes configured: send to all sinks
        all_sink_ids

      [] ->
        # Empty routes: send to all sinks
        all_sink_ids

      routes when is_list(routes) ->
        routes
        |> Enum.filter(&matches?(event_name, &1.match))
        |> Enum.flat_map(& &1.sinks)
        |> Enum.uniq()
    end
  end

  @doc """
  Checks if an event name matches a pattern.
  Supports simple glob patterns with `*`.
  """
  @spec matches?(String.t(), String.t()) :: boolean()
  def matches?(event_name, pattern) do
    regex =
      pattern
      |> Regex.escape()
      |> String.replace("\\*", ".*")

    Regex.match?(~r/^#{regex}$/, event_name)
  end

  defp get_all_sink_ids do
    :fyi
    |> Application.get_env(:sinks, [])
    |> Enum.map(fn {mod, _config} -> mod.id() end)
  end
end
