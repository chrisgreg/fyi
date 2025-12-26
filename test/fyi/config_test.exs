defmodule FYI.ConfigTest do
  use ExUnit.Case, async: true

  alias FYI.Config

  describe "emoji_for/2" do
    test "returns override when provided" do
      assert Config.emoji_for("purchase.created", "🎉") == "🎉"
    end

    test "returns nil when no emoji configured" do
      # Clear any existing config
      original = Application.get_env(:fyi, :emoji)
      original_emojis = Application.get_env(:fyi, :emojis)
      Application.delete_env(:fyi, :emoji)
      Application.delete_env(:fyi, :emojis)

      assert Config.emoji_for("random.event") == nil

      # Restore
      if original, do: Application.put_env(:fyi, :emoji, original)
      if original_emojis, do: Application.put_env(:fyi, :emojis, original_emojis)
    end

    test "matches pattern from emojis config" do
      original = Application.get_env(:fyi, :emojis)
      Application.put_env(:fyi, :emojis, %{"purchase.*" => "💰", "error.*" => "🚨"})

      assert Config.emoji_for("purchase.created") == "💰"
      assert Config.emoji_for("purchase.updated") == "💰"
      assert Config.emoji_for("error.critical") == "🚨"

      # Restore
      if original do
        Application.put_env(:fyi, :emojis, original)
      else
        Application.delete_env(:fyi, :emojis)
      end
    end

    test "falls back to default emoji" do
      original = Application.get_env(:fyi, :emoji)
      original_emojis = Application.get_env(:fyi, :emojis)
      Application.put_env(:fyi, :emoji, "📣")
      Application.delete_env(:fyi, :emojis)

      assert Config.emoji_for("unmatched.event") == "📣"

      # Restore
      if original do
        Application.put_env(:fyi, :emoji, original)
      else
        Application.delete_env(:fyi, :emoji)
      end

      if original_emojis, do: Application.put_env(:fyi, :emojis, original_emojis)
    end

    test "override takes precedence over pattern match" do
      original = Application.get_env(:fyi, :emojis)
      Application.put_env(:fyi, :emojis, %{"purchase.*" => "💰"})

      assert Config.emoji_for("purchase.created", "🎁") == "🎁"

      # Restore
      if original do
        Application.put_env(:fyi, :emojis, original)
      else
        Application.delete_env(:fyi, :emojis)
      end
    end
  end

  describe "app_name/0" do
    test "returns configured app name" do
      original = Application.get_env(:fyi, :app_name)
      Application.put_env(:fyi, :app_name, "TestApp")

      assert Config.app_name() == "TestApp"

      # Restore
      if original do
        Application.put_env(:fyi, :app_name, original)
      else
        Application.delete_env(:fyi, :app_name)
      end
    end

    test "converts atom to string" do
      original = Application.get_env(:fyi, :app_name)
      Application.put_env(:fyi, :app_name, :my_app)

      assert Config.app_name() == "my_app"

      # Restore
      if original do
        Application.put_env(:fyi, :app_name, original)
      else
        Application.delete_env(:fyi, :app_name)
      end
    end
  end

  describe "message_prefix/2" do
    test "returns empty string when no emoji or app name" do
      original_emoji = Application.get_env(:fyi, :emoji)
      original_app = Application.get_env(:fyi, :app_name)
      original_otp = Application.get_env(:fyi, :otp_app)
      Application.delete_env(:fyi, :emoji)
      Application.delete_env(:fyi, :app_name)
      Application.delete_env(:fyi, :otp_app)

      assert Config.message_prefix("test.event") == ""

      # Restore
      if original_emoji, do: Application.put_env(:fyi, :emoji, original_emoji)
      if original_app, do: Application.put_env(:fyi, :app_name, original_app)
      if original_otp, do: Application.put_env(:fyi, :otp_app, original_otp)
    end

    test "includes emoji and app name with space" do
      original_emoji = Application.get_env(:fyi, :emoji)
      original_app = Application.get_env(:fyi, :app_name)
      Application.put_env(:fyi, :emoji, "🔔")
      Application.put_env(:fyi, :app_name, "MyApp")

      assert Config.message_prefix("test.event") == "🔔 [MyApp] "

      # Restore
      if original_emoji do
        Application.put_env(:fyi, :emoji, original_emoji)
      else
        Application.delete_env(:fyi, :emoji)
      end

      if original_app do
        Application.put_env(:fyi, :app_name, original_app)
      else
        Application.delete_env(:fyi, :app_name)
      end
    end

    test "uses emoji override" do
      original_emoji = Application.get_env(:fyi, :emoji)
      original_app = Application.get_env(:fyi, :app_name)
      Application.put_env(:fyi, :emoji, "🔔")
      Application.put_env(:fyi, :app_name, "MyApp")

      assert Config.message_prefix("test.event", "🚨") == "🚨 [MyApp] "

      # Restore
      if original_emoji do
        Application.put_env(:fyi, :emoji, original_emoji)
      else
        Application.delete_env(:fyi, :emoji)
      end

      if original_app do
        Application.put_env(:fyi, :app_name, original_app)
      else
        Application.delete_env(:fyi, :app_name)
      end
    end
  end
end

