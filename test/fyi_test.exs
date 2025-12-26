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
  end
end
