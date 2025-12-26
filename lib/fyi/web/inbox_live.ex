if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule FYI.Web.InboxLive do
    @moduledoc """
    LiveView for the FYI admin inbox.

    Displays recent events with filtering and detail view.
    """

    use Phoenix.LiveView

    alias FYI.Schema.Event

    @per_page 50

    @impl true
    def mount(_params, _session, socket) do
      {:ok,
       socket
       |> assign(:page_title, "FYI Events")
       |> assign(:filter_name, "")
       |> assign(:filter_actor, "")
       |> assign(:selected_event, nil)
       |> load_events()}
    end

    @impl true
    def handle_params(params, _uri, socket) do
      case params do
        %{"id" => id} ->
          {:noreply, load_event_detail(socket, id)}

        _ ->
          {:noreply, assign(socket, :selected_event, nil)}
      end
    end

    @impl true
    def handle_event("filter", %{"name" => name, "actor" => actor}, socket) do
      {:noreply,
       socket
       |> assign(:filter_name, name)
       |> assign(:filter_actor, actor)
       |> load_events()}
    end

    @impl true
    def handle_event("clear_filters", _, socket) do
      {:noreply,
       socket
       |> assign(:filter_name, "")
       |> assign(:filter_actor, "")
       |> load_events()}
    end

    @impl true
    def handle_event("close_detail", _, socket) do
      {:noreply,
       socket
       |> assign(:selected_event, nil)
       |> push_patch(to: "/fyi")}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <div class="fyi-inbox">
        <style>
          .fyi-inbox {
            font-family: system-ui, -apple-system, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 2rem;
          }
          .fyi-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 2rem;
          }
          .fyi-header h1 {
            font-size: 1.5rem;
            font-weight: 600;
            color: #1a1a2e;
          }
          .fyi-filters {
            display: flex;
            gap: 1rem;
            margin-bottom: 1.5rem;
          }
          .fyi-filters input {
            padding: 0.5rem 1rem;
            border: 1px solid #e2e8f0;
            border-radius: 6px;
            font-size: 0.875rem;
          }
          .fyi-filters button {
            padding: 0.5rem 1rem;
            background: #6366f1;
            color: white;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 0.875rem;
          }
          .fyi-filters button.secondary {
            background: #e2e8f0;
            color: #64748b;
          }
          .fyi-events {
            background: white;
            border-radius: 12px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
            overflow: hidden;
          }
          .fyi-event-row {
            display: grid;
            grid-template-columns: 1fr 150px 150px 120px;
            padding: 1rem 1.5rem;
            border-bottom: 1px solid #f1f5f9;
            align-items: center;
            text-decoration: none;
            color: inherit;
            transition: background 0.15s;
          }
          .fyi-event-row:hover {
            background: #f8fafc;
          }
          .fyi-event-name {
            font-weight: 500;
            color: #1e293b;
          }
          .fyi-event-actor {
            color: #64748b;
            font-size: 0.875rem;
          }
          .fyi-event-tags {
            display: flex;
            gap: 0.5rem;
            flex-wrap: wrap;
          }
          .fyi-tag {
            background: #e0e7ff;
            color: #4338ca;
            padding: 0.25rem 0.5rem;
            border-radius: 4px;
            font-size: 0.75rem;
          }
          .fyi-event-time {
            color: #94a3b8;
            font-size: 0.875rem;
            text-align: right;
          }
          .fyi-empty {
            padding: 3rem;
            text-align: center;
            color: #94a3b8;
          }
          .fyi-modal-overlay {
            position: fixed;
            inset: 0;
            background: rgba(0,0,0,0.5);
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 50;
          }
          .fyi-modal {
            background: white;
            border-radius: 12px;
            max-width: 600px;
            width: 90%;
            max-height: 80vh;
            overflow: auto;
          }
          .fyi-modal-header {
            padding: 1.5rem;
            border-bottom: 1px solid #e2e8f0;
            display: flex;
            justify-content: space-between;
            align-items: center;
          }
          .fyi-modal-header h2 {
            font-size: 1.25rem;
            font-weight: 600;
          }
          .fyi-modal-close {
            background: none;
            border: none;
            font-size: 1.5rem;
            cursor: pointer;
            color: #94a3b8;
          }
          .fyi-modal-body {
            padding: 1.5rem;
          }
          .fyi-detail-row {
            margin-bottom: 1rem;
          }
          .fyi-detail-label {
            font-size: 0.75rem;
            text-transform: uppercase;
            color: #64748b;
            margin-bottom: 0.25rem;
          }
          .fyi-detail-value {
            color: #1e293b;
          }
          .fyi-payload {
            background: #f8fafc;
            padding: 1rem;
            border-radius: 8px;
            font-family: monospace;
            font-size: 0.875rem;
            white-space: pre-wrap;
            overflow-x: auto;
          }
        </style>

        <div class="fyi-header">
          <h1>📬 FYI Events</h1>
        </div>

        <form phx-change="filter" class="fyi-filters">
          <input
            type="text"
            name="name"
            value={@filter_name}
            placeholder="Filter by event name..."
            phx-debounce="300"
          />
          <input
            type="text"
            name="actor"
            value={@filter_actor}
            placeholder="Filter by actor..."
            phx-debounce="300"
          />
          <button type="button" phx-click="clear_filters" class="secondary">Clear</button>
        </form>

        <div class="fyi-events">
          <%= if Enum.empty?(@events) do %>
            <div class="fyi-empty">
              <p>No events found</p>
            </div>
          <% else %>
            <%= for event <- @events do %>
              <.link patch={"/fyi/events/#{event.id}"} class="fyi-event-row">
                <span class="fyi-event-name"><%= event.name %></span>
                <span class="fyi-event-actor"><%= event.actor || "-" %></span>
                <span class="fyi-event-tags">
                  <%= for {k, v} <- event.tags || %{} do %>
                    <span class="fyi-tag"><%= k %>: <%= v %></span>
                  <% end %>
                </span>
                <span class="fyi-event-time"><%= format_time(event.inserted_at) %></span>
              </.link>
            <% end %>
          <% end %>
        </div>

        <%= if @selected_event do %>
          <div class="fyi-modal-overlay" phx-click="close_detail">
            <div class="fyi-modal" phx-click-away="close_detail">
              <div class="fyi-modal-header">
                <h2><%= @selected_event.name %></h2>
                <button class="fyi-modal-close" phx-click="close_detail">&times;</button>
              </div>
              <div class="fyi-modal-body">
                <div class="fyi-detail-row">
                  <div class="fyi-detail-label">Event ID</div>
                  <div class="fyi-detail-value"><%= @selected_event.id %></div>
                </div>
                <div class="fyi-detail-row">
                  <div class="fyi-detail-label">Actor</div>
                  <div class="fyi-detail-value"><%= @selected_event.actor || "-" %></div>
                </div>
                <div class="fyi-detail-row">
                  <div class="fyi-detail-label">Source</div>
                  <div class="fyi-detail-value"><%= @selected_event.source || "-" %></div>
                </div>
                <div class="fyi-detail-row">
                  <div class="fyi-detail-label">Time</div>
                  <div class="fyi-detail-value"><%= @selected_event.inserted_at %></div>
                </div>
                <div class="fyi-detail-row">
                  <div class="fyi-detail-label">Tags</div>
                  <div class="fyi-detail-value">
                    <%= if map_size(@selected_event.tags || %{}) == 0 do %>
                      -
                    <% else %>
                      <div class="fyi-event-tags">
                        <%= for {k, v} <- @selected_event.tags do %>
                          <span class="fyi-tag"><%= k %>: <%= v %></span>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
                <div class="fyi-detail-row">
                  <div class="fyi-detail-label">Payload</div>
                  <pre class="fyi-payload"><%= Jason.encode!(@selected_event.payload, pretty: true) %></pre>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
      """
    end

    defp load_events(socket) do
      repo = Application.get_env(:fyi, :repo)

      if repo && Code.ensure_loaded?(Event) do
        import Ecto.Query

        query =
          from(e in Event,
            order_by: [desc: e.inserted_at],
            limit: @per_page
          )

        query =
          if socket.assigns.filter_name != "" do
            name_filter = "%#{socket.assigns.filter_name}%"
            from(e in query, where: ilike(e.name, ^name_filter))
          else
            query
          end

        query =
          if socket.assigns.filter_actor != "" do
            actor_filter = "%#{socket.assigns.filter_actor}%"
            from(e in query, where: ilike(e.actor, ^actor_filter))
          else
            query
          end

        events = repo.all(query)
        assign(socket, :events, events)
      else
        assign(socket, :events, [])
      end
    end

    defp load_event_detail(socket, id) do
      repo = Application.get_env(:fyi, :repo)

      if repo && Code.ensure_loaded?(Event) do
        case repo.get(Event, id) do
          nil -> assign(socket, :selected_event, nil)
          event -> assign(socket, :selected_event, event)
        end
      else
        assign(socket, :selected_event, nil)
      end
    end

    defp format_time(nil), do: "-"

    defp format_time(datetime) do
      Calendar.strftime(datetime, "%b %d, %H:%M")
    end
  end
end
