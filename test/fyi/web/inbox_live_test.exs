defmodule FYI.Web.InboxLiveTest do
  use ExUnit.Case, async: true

  alias FYI.Web.InboxLive

  describe "extract_route_prefix_from_uri/1" do
    test "extracts route prefix from root-level /fyi path" do
      uri = "http://localhost:4000/fyi?range=7d"
      assert InboxLive.extract_route_prefix_from_uri(uri) == "/fyi"
    end

    test "extracts route prefix from nested /admin/fyi path" do
      uri = "http://localhost:4000/admin/fyi?range=7d"
      assert InboxLive.extract_route_prefix_from_uri(uri) == "/admin/fyi"
    end

    test "extracts route prefix from deeply nested path" do
      uri = "http://localhost:4000/admin/dashboard/fyi?range=7d"
      assert InboxLive.extract_route_prefix_from_uri(uri) == "/admin/dashboard/fyi"
    end

    test "extracts route prefix from event detail URL at root level" do
      uri = "http://localhost:4000/fyi/events/123?range=7d"
      assert InboxLive.extract_route_prefix_from_uri(uri) == "/fyi"
    end

    test "extracts route prefix from event detail URL in nested scope" do
      uri = "http://localhost:4000/admin/fyi/events/456?range=7d&type=user"
      assert InboxLive.extract_route_prefix_from_uri(uri) == "/admin/fyi"
    end

    test "handles URI without query params" do
      uri = "http://localhost:4000/admin/fyi"
      assert InboxLive.extract_route_prefix_from_uri(uri) == "/admin/fyi"
    end

    test "handles URI with trailing slash" do
      uri = "http://localhost:4000/admin/fyi/"
      assert InboxLive.extract_route_prefix_from_uri(uri) == "/admin/fyi/"
    end
  end

  describe "event_url/4" do
    test "generates correct URL for root-level scope" do
      socket = %{assigns: %{route_prefix: "/fyi"}}
      url = InboxLive.event_url(socket, "event-123", "7d", "")
      assert url == "/fyi/events/event-123?range=7d"
    end

    test "generates correct URL for nested scope" do
      socket = %{assigns: %{route_prefix: "/admin/fyi"}}
      url = InboxLive.event_url(socket, "event-456", "24h", "user.signup")
      assert url == "/admin/fyi/events/event-456?range=24h&type=user.signup"
    end

    test "generates correct URL without event type filter" do
      socket = %{assigns: %{route_prefix: "/admin/dashboard/fyi"}}
      url = InboxLive.event_url(socket, "event-789", "1h", "")
      assert url == "/admin/dashboard/fyi/events/event-789?range=1h"
    end
  end

  describe "build_url/3" do
    test "generates correct index URL for root-level scope" do
      socket = %{assigns: %{route_prefix: "/fyi"}}
      url = InboxLive.build_url(socket, "7d", "")
      assert url == "/fyi?range=7d"
    end

    test "generates correct index URL for nested scope" do
      socket = %{assigns: %{route_prefix: "/admin/fyi"}}
      url = InboxLive.build_url(socket, "24h", "error.occurred")
      assert url == "/admin/fyi?range=24h&type=error.occurred"
    end

    test "generates correct URL without event type" do
      socket = %{assigns: %{route_prefix: "/admin/dashboard/fyi"}}
      url = InboxLive.build_url(socket, "1h", "")
      assert url == "/admin/dashboard/fyi?range=1h"
    end
  end
end
