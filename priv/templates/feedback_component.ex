defmodule <%= @web_module %>.FYI.FeedbackComponent do
  @moduledoc """
  Feedback component for collecting user feedback.

  Customize the styling, categories, and behavior as needed.

  ## Usage

      <.live_component module={<%= @web_module %>.FYI.FeedbackComponent} id="feedback" />

  Or use the convenience function:

      import <%= @web_module %>.FYI.FeedbackComponent
      <.feedback_button />
  """

  use Phoenix.LiveComponent

  @default_categories [
    {"bug", "Bug Report"},
    {"feature", "Feature Request"},
    {"improvement", "Improvement"},
    {"other", "Other"}
  ]

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:show_modal, false)
     |> assign(:submitted, false)}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:button_label, fn -> "Feedback" end)
      |> assign_new(:button_icon, fn -> "💬" end)
      |> assign_new(:title, fn -> "Send Feedback" end)
      |> assign_new(:categories, fn -> @default_categories end)

    {:ok, socket}
  end

  @impl true
  def handle_event("open", _, socket) do
    {:noreply, assign(socket, :show_modal, true)}
  end

  @impl true
  def handle_event("close", _, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> assign(:submitted, false)}
  end

  @impl true
  def handle_event("submit", %{"message" => message, "category" => category, "email" => email}, socket) do
    payload = %{
      message: message,
      category: category,
      email: email
    }

    # Get actor from socket assigns if available
    actor = socket.assigns[:current_user_id] || socket.assigns[:user_id]

    FYI.emit("feedback.submitted", payload, actor: actor, tags: %{category: category})

    {:noreply, assign(socket, :submitted, true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <button
        type="button"
        class="fixed bottom-6 right-6 z-40 flex items-center gap-2 px-4 py-2.5
               bg-blue-500 hover:bg-blue-600 text-white text-sm font-medium
               rounded-lg shadow-md hover:shadow-lg
               transition-all duration-200 cursor-pointer"
        phx-click="open"
        phx-target={@myself}
      >
        <span>{@button_icon}</span>
        <span>{@button_label}</span>
      </button>

      <div :if={@show_modal} class="fixed inset-0 z-50 flex items-center justify-center bg-gray-900/50">
        <div
          class="w-[90%] max-w-md bg-white rounded-lg shadow-xl border border-gray-200"
          phx-click-away="close"
          phx-target={@myself}
        >
          <div class="flex items-center justify-between px-5 py-4 border-b border-gray-200">
            <h2 class="text-base font-semibold text-gray-900">{@title}</h2>
            <button
              type="button"
              class="text-gray-400 hover:text-gray-600 text-xl leading-none"
              phx-click="close"
              phx-target={@myself}
            >
              &times;
            </button>
          </div>

          <div :if={@submitted} class="p-10 text-center">
            <div class="text-4xl mb-3">✅</div>
            <h3 class="text-base font-semibold text-gray-900 mb-1">Thank you!</h3>
            <p class="text-sm text-gray-500">Your feedback has been received.</p>
          </div>

          <div :if={!@submitted} class="p-5">
            <form phx-submit="submit" phx-target={@myself} class="space-y-4">
              <div>
                <label class="block text-xs font-medium text-gray-500 uppercase tracking-wide mb-1.5">
                  Category
                </label>
                <select
                  name="category"
                  class="w-full px-3 py-2 text-sm border border-gray-200 rounded-md bg-white
                         focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                >
                  <option value="">Select a category...</option>
                  <option :for={{value, label} <- @categories} value={value}>{label}</option>
                </select>
              </div>

              <div>
                <label class="block text-xs font-medium text-gray-500 uppercase tracking-wide mb-1.5">
                  Message *
                </label>
                <textarea
                  name="message"
                  required
                  placeholder="Tell us what's on your mind..."
                  class="w-full px-3 py-2 text-sm border border-gray-200 rounded-md min-h-[100px] resize-y
                         focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                ></textarea>
              </div>

              <div>
                <label class="block text-xs font-medium text-gray-500 uppercase tracking-wide mb-1.5">
                  Email (optional)
                </label>
                <input
                  type="email"
                  name="email"
                  placeholder="your@email.com"
                  class="w-full px-3 py-2 text-sm border border-gray-200 rounded-md
                         focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                />
              </div>

              <button
                type="submit"
                class="w-full py-2.5 px-4 bg-blue-500 hover:bg-blue-600 text-white text-sm font-medium rounded-md transition-colors"
              >
                Send Feedback
              </button>
            </form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Convenience function component for rendering the feedback button.

  ## Examples

      <.feedback_button />

      <.feedback_button title="Report an Issue" button_label="Report" button_icon="🐛" />
  """
  def feedback_button(assigns) do
    assigns =
      assigns
      |> assign_new(:id, fn -> "fyi-feedback" end)
      |> assign_new(:button_label, fn -> "Feedback" end)
      |> assign_new(:button_icon, fn -> "💬" end)
      |> assign_new(:title, fn -> "Send Feedback" end)
      |> assign_new(:categories, fn -> @default_categories end)

    ~H"""
    <.live_component
      module={__MODULE__}
      id={@id}
      button_label={@button_label}
      button_icon={@button_icon}
      title={@title}
      categories={@categories}
    />
    """
  end
end
