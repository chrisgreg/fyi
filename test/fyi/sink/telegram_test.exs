defmodule FYI.Sink.TelegramTest do
  use ExUnit.Case, async: true

  alias FYI.Sink.Telegram

  describe "id/0" do
    test "returns :telegram" do
      assert Telegram.id() == :telegram
    end
  end

  describe "init/1" do
    test "initializes with valid config" do
      config = %{token: "123:ABC", chat_id: "-1001234"}
      assert {:ok, state} = Telegram.init(config)
      assert state.token == "123:ABC"
      assert state.chat_id == "-1001234"
      assert state.parse_mode == "HTML"
    end

    test "accepts integer chat_id" do
      config = %{token: "123:ABC", chat_id: -1_001_234}
      assert {:ok, state} = Telegram.init(config)
      assert state.chat_id == "-1001234"
    end

    test "returns error without required fields" do
      assert {:error, _} = Telegram.init(%{token: "123:ABC"})
      assert {:error, _} = Telegram.init(%{chat_id: "123"})
      assert {:error, _} = Telegram.init(%{})
    end
  end
end
