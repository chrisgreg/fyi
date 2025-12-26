defmodule FYITest do
  use ExUnit.Case, async: true

  alias FYI.Event

  describe "Event.new/3" do
    test "creates an event with required fields" do
      event = Event.new("user.signup", %{email: "test@example.com"})

      assert event.name == "user.signup"
      assert event.payload == %{email: "test@example.com"}
      assert is_binary(event.id)
      assert %DateTime{} = event.occurred_at
    end

    test "accepts optional actor" do
      event = Event.new("purchase.created", %{}, actor: "user_123")
      assert event.actor == "user_123"
    end

    test "accepts optional tags" do
      event = Event.new("purchase.created", %{}, tags: %{plan: "pro"})
      assert event.tags == %{plan: "pro"}
    end

    test "converts actor to string" do
      event = Event.new("test.event", %{}, actor: 123)
      assert event.actor == "123"
    end

    test "accepts optional source" do
      event = Event.new("api.request", %{}, source: "web")
      assert event.source == "web"
    end

    test "accepts optional emoji" do
      event = Event.new("error.critical", %{}, emoji: "🚨")
      assert event.emoji == "🚨"
    end

    test "generates unique IDs" do
      event1 = Event.new("test", %{})
      event2 = Event.new("test", %{})
      assert event1.id != event2.id
    end

    test "defaults to empty payload" do
      event = Event.new("test.event")
      assert event.payload == %{}
    end

    test "defaults to empty tags" do
      event = Event.new("test.event", %{})
      assert event.tags == %{}
    end

    test "nil actor stays nil" do
      event = Event.new("test.event", %{}, actor: nil)
      assert event.actor == nil
    end
  end

  describe "Router.matches?/2" do
    alias FYI.Router

    test "matches exact event names" do
      assert Router.matches?("user.signup", "user.signup")
      refute Router.matches?("user.signup", "user.login")
    end

    test "matches wildcard patterns" do
      assert Router.matches?("purchase.created", "purchase.*")
      assert Router.matches?("purchase.updated", "purchase.*")
      refute Router.matches?("user.signup", "purchase.*")
    end

    test "matches prefix patterns" do
      assert Router.matches?("app.user.created", "app.*")
      assert Router.matches?("app.purchase.created", "app.*")
    end

    test "matches all with single wildcard" do
      assert Router.matches?("anything.here", "*")
      assert Router.matches?("single", "*")
    end

    test "does not match partial names without wildcard" do
      refute Router.matches?("user.signup.complete", "user.signup")
      refute Router.matches?("user", "user.signup")
    end

    test "matches middle wildcards" do
      assert Router.matches?("app.user.created", "app.*.created")
      assert Router.matches?("app.purchase.created", "app.*.created")
      refute Router.matches?("app.user.updated", "app.*.created")
    end
  end

  describe "Router.route/1" do
    alias FYI.Router

    test "returns empty list when no sinks configured" do
      original = Application.get_env(:fyi, :sinks)
      Application.delete_env(:fyi, :sinks)

      assert Router.route("test.event") == []

      if original, do: Application.put_env(:fyi, :sinks, original)
    end
  end
end
