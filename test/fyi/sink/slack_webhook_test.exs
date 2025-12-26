defmodule FYI.Sink.SlackWebhookTest do
  use ExUnit.Case, async: true

  alias FYI.Sink.SlackWebhook

  describe "id/0" do
    test "returns :slack" do
      assert SlackWebhook.id() == :slack
    end
  end

  describe "init/1" do
    test "initializes with valid config" do
      config = %{url: "https://hooks.slack.com/test"}
      assert {:ok, state} = SlackWebhook.init(config)
      assert state.url == "https://hooks.slack.com/test"
    end

    test "accepts optional username and icon_emoji" do
      config = %{url: "https://hooks.slack.com/test", username: "FYI Bot", icon_emoji: ":bell:"}
      assert {:ok, state} = SlackWebhook.init(config)
      assert state.username == "FYI Bot"
      assert state.icon_emoji == ":bell:"
    end

    test "returns error without url" do
      assert {:error, _} = SlackWebhook.init(%{})
    end
  end
end
