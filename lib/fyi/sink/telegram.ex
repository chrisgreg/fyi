defmodule FYI.Sink.Telegram do
  @moduledoc """
  Telegram bot sink.

  Sends events to a Telegram chat via the Bot API.

  ## Configuration

      {FYI.Sink.Telegram, %{
        token: "123456:ABC-DEF...",
        chat_id: "-1001234567890"
      }}

  ## Options

  - `:token` (required) - Telegram bot token from @BotFather
  - `:chat_id` (required) - Chat/group/channel ID to send messages to
  - `:parse_mode` - Message parse mode ("HTML" or "MarkdownV2", default: "HTML")
  """

  @behaviour FYI.Sink

  alias FYI.Event

  @telegram_api_base "https://api.telegram.org"

  @impl true
  def id, do: :telegram

  @impl true
  def init(%{token: token, chat_id: chat_id} = config)
      when is_binary(token) and (is_binary(chat_id) or is_integer(chat_id)) do
    {:ok,
     %{
       token: token,
       chat_id: to_string(chat_id),
       parse_mode: config[:parse_mode] || "HTML"
     }}
  end

  def init(_config) do
    {:error, "Telegram sink requires :token and :chat_id in configuration"}
  end

  @impl true
  def deliver(%Event{} = event, state) do
    url = "#{@telegram_api_base}/bot#{state.token}/sendMessage"

    payload = %{
      chat_id: state.chat_id,
      text: format_message(event, state.parse_mode),
      parse_mode: state.parse_mode
    }

    case FYI.Client.post(url, json: payload) do
      {:ok, %{status: 200, body: %{"ok" => true}}} ->
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, "Telegram returned #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp format_message(event, "HTML") do
    prefix = FYI.Config.message_prefix(event.name, event.emoji) |> escape_html()
    actor_text = if event.actor, do: " by <code>#{escape_html(event.actor)}</code>", else: ""
    tags_text = format_tags_html(event.tags)
    payload_text = format_payload_html(event.payload)

    """
    #{prefix}<b>#{escape_html(event.name)}</b>#{actor_text}#{tags_text}
    #{payload_text}
    """
    |> String.trim()
  end

  defp format_message(event, _parse_mode) do
    # Plain text fallback
    prefix = FYI.Config.message_prefix(event.name, event.emoji)
    actor_text = if event.actor, do: " by #{event.actor}", else: ""
    tags_text = format_tags_plain(event.tags)
    payload_text = format_payload_plain(event.payload)

    """
    #{prefix}#{event.name}#{actor_text}#{tags_text}
    #{payload_text}
    """
    |> String.trim()
  end

  defp format_tags_html(tags) when map_size(tags) == 0, do: ""

  defp format_tags_html(tags) do
    formatted =
      tags
      |> Enum.map(fn {k, v} ->
        "<code>#{escape_html(to_string(k))}:#{escape_html(to_string(v))}</code>"
      end)
      |> Enum.join(" ")

    " [#{formatted}]"
  end

  defp format_tags_plain(tags) when map_size(tags) == 0, do: ""

  defp format_tags_plain(tags) do
    formatted =
      tags
      |> Enum.map(fn {k, v} -> "#{k}:#{v}" end)
      |> Enum.join(" ")

    " [#{formatted}]"
  end

  defp format_payload_html(payload) when map_size(payload) == 0, do: ""

  defp format_payload_html(payload) do
    payload
    |> Enum.map(fn {k, v} -> "• #{escape_html(to_string(k))}: #{escape_html(inspect(v))}" end)
    |> Enum.join("\n")
  end

  defp format_payload_plain(payload) when map_size(payload) == 0, do: ""

  defp format_payload_plain(payload) do
    payload
    |> Enum.map(fn {k, v} -> "• #{k}: #{inspect(v)}" end)
    |> Enum.join("\n")
  end

  defp escape_html(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end
end
