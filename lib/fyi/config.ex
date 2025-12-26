defmodule FYI.Config do
  @moduledoc """
  Configuration helpers for FYI.
  """

  @doc """
  Returns the configured app name, or nil if not set.

  The app name is included in Slack/Telegram messages to identify
  which app an event came from when multiple apps share a channel.

  ## Configuration

      config :fyi, app_name: "MyApp"

  If not configured, falls back to the OTP app name in a human-readable format.
  """
  @spec app_name() :: String.t() | nil
  def app_name do
    case Application.get_env(:fyi, :app_name) do
      nil -> infer_app_name()
      name when is_binary(name) -> name
      name when is_atom(name) -> to_string(name)
    end
  end

  @doc """
  Returns the configured default emoji prefix for notifications.

  ## Configuration

      config :fyi, emoji: "🔔"
  """
  @spec emoji() :: String.t() | nil
  def emoji do
    Application.get_env(:fyi, :emoji)
  end

  @doc """
  Returns the emoji for a specific event name.

  Checks the `:emojis` config map first, then falls back to the default `:emoji`.

  ## Configuration

      config :fyi,
        emoji: "📣",  # default fallback
        emojis: %{
          "purchase.*" => "💰",
          "user.signup" => "👋",
          "feedback.*" => "💬",
          "error.*" => "🚨"
        }
  """
  @spec emoji_for(String.t(), String.t() | nil) :: String.t() | nil
  def emoji_for(event_name, override \\ nil) do
    override || find_emoji_match(event_name) || emoji()
  end

  defp find_emoji_match(event_name) do
    emojis = Application.get_env(:fyi, :emojis, %{})

    Enum.find_value(emojis, fn {pattern, emoji} ->
      if matches_pattern?(event_name, pattern), do: emoji
    end)
  end

  defp matches_pattern?(event_name, pattern) do
    regex =
      pattern
      |> Regex.escape()
      |> String.replace("\\*", ".*")

    Regex.match?(~r/^#{regex}$/, event_name)
  end

  @doc """
  Returns the formatted prefix for sink messages (emoji + app name).
  """
  @spec message_prefix(String.t(), String.t() | nil) :: String.t()
  def message_prefix(event_name, emoji_override \\ nil) do
    parts = [emoji_for(event_name, emoji_override), app_name_bracket()]
    parts |> Enum.reject(&is_nil/1) |> Enum.join(" ") |> maybe_add_space()
  end

  defp app_name_bracket do
    case app_name() do
      nil -> nil
      name -> "[#{name}]"
    end
  end

  defp maybe_add_space(""), do: ""
  defp maybe_add_space(str), do: str <> " "

  defp infer_app_name do
    case Application.get_env(:fyi, :otp_app) do
      nil -> nil
      app -> app |> to_string() |> humanize()
    end
  end

  defp humanize(string) do
    string
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
