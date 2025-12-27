defmodule FYI.Sink.SlackWebhook do
  @moduledoc """
  Slack incoming webhook sink.

  Sends events to a Slack channel via incoming webhooks.

  ## Configuration

      {FYI.Sink.SlackWebhook, %{url: "https://hooks.slack.com/services/..."}}

  ## Options

  - `:url` (required) - Slack incoming webhook URL
  - `:username` - Bot username to display (optional)
  - `:icon_emoji` - Emoji icon for the bot (optional, e.g., ":bell:")
  """

  @behaviour FYI.Sink

  alias FYI.Event

  @impl true
  def id, do: :slack

  @impl true
  def init(%{url: url} = config) when is_binary(url) do
    {:ok,
     %{
       url: url,
       username: config[:username],
       icon_emoji: config[:icon_emoji]
     }}
  end

  def init(_config) do
    {:error, "Slack sink requires :url in configuration"}
  end

  @impl true
  def deliver(%Event{} = event, state) do
    payload = build_payload(event, state)

    case FYI.Client.post(state.url, json: payload) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, "Slack returned #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_payload(event, state) do
    %{text: format_message(event)}
    |> maybe_add(:username, state[:username])
    |> maybe_add(:icon_emoji, state[:icon_emoji])
  end

  defp format_message(event) do
    prefix = FYI.Config.message_prefix(event.name, event.emoji)
    actor_text = if event.actor, do: " by `#{event.actor}`", else: ""
    tags_text = format_tags(event.tags)
    payload_text = format_payload(event.payload)

    """
    #{prefix}*#{event.name}*#{actor_text}#{tags_text}
    #{payload_text}
    """
    |> String.trim()
  end

  defp format_tags(tags) when map_size(tags) == 0, do: ""

  defp format_tags(tags) do
    formatted =
      tags
      |> Enum.map(fn {k, v} -> "`#{k}:#{v}`" end)
      |> Enum.join(" ")

    " [#{formatted}]"
  end

  defp format_payload(payload) when map_size(payload) == 0, do: ""

  defp format_payload(payload) do
    payload
    |> Enum.map(fn {k, v} -> "• #{k}: #{inspect(v)}" end)
    |> Enum.join("\n")
  end

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, key, value), do: Map.put(map, key, value)
end
