defmodule FYI.MultiTest do
  use ExUnit.Case, async: true

  alias Ecto.Multi
  alias FYI.Multi, as: FYIMulti

  describe "emit/3 with callback" do
    test "adds a run operation to the multi" do
      multi =
        Multi.new()
        |> FYIMulti.emit("user.created", fn _changes -> %{payload: %{}} end)

      assert Keyword.has_key?(multi.operations, :"fyi_event_user.created")
    end

    test "generates unique operation names for different events" do
      multi =
        Multi.new()
        |> FYIMulti.emit("event.one", fn _ -> %{payload: %{}} end)
        |> FYIMulti.emit("event.two", fn _ -> %{payload: %{}} end)

      assert Keyword.has_key?(multi.operations, :"fyi_event_event.one")
      assert Keyword.has_key?(multi.operations, :"fyi_event_event.two")
    end

    test "callback receives changes from previous operations" do
      # This is a structural test - we verify the multi is set up correctly
      callback = fn changes ->
        assert is_map(changes)
        %{payload: %{received: true}}
      end

      multi =
        Multi.new()
        |> FYIMulti.emit("test.event", callback)

      assert length(multi.operations) == 1
    end
  end

  describe "emit/4 with static payload" do
    test "adds a run operation to the multi" do
      multi =
        Multi.new()
        |> FYIMulti.emit("subscription.cancelled", %{reason: "user_requested"})

      assert Keyword.has_key?(multi.operations, :"fyi_event_subscription.cancelled")
    end

    test "accepts optional opts" do
      multi =
        Multi.new()
        |> FYIMulti.emit("test.event", %{}, actor: "user_123", source: "api")

      assert Keyword.has_key?(multi.operations, :"fyi_event_test.event")
    end
  end
end

