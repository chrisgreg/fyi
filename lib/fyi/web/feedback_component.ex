if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule FYI.Web.FeedbackComponent do
    @moduledoc """
    Drop-in feedback component for collecting user feedback.

    ## Usage in LiveView

        <FYI.Web.FeedbackComponent.feedback_button />

    Or with custom styling:

        <FYI.Web.FeedbackComponent.feedback_button class="my-custom-class" />

    The component handles its own state and emits a `feedback.submitted` event
    when feedback is submitted.
    """

    use Phoenix.LiveComponent

    @impl true
    def mount(socket) do
      {:ok,
       socket
       |> assign(:show_modal, false)
       |> assign(:form, to_form(%{"message" => "", "category" => "", "email" => ""}))
       |> assign(:submitted, false)}
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
       |> assign(:submitted, false)
       |> assign(:form, to_form(%{"message" => "", "category" => "", "email" => ""}))}
    end

    @impl true
    def handle_event(
          "submit",
          %{"message" => message, "category" => category, "email" => email},
          socket
        ) do
      payload = %{
        message: message,
        category: category,
        email: email
      }

      # Get actor from socket assigns if available
      actor = socket.assigns[:current_user_id] || socket.assigns[:user_id]

      FYI.emit("feedback.submitted", payload, actor: actor, tags: %{category: category})

      {:noreply,
       socket
       |> assign(:submitted, true)}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <div class="fyi-feedback-wrapper">
        <style>
          .fyi-feedback-btn {
            position: fixed;
            bottom: 1.5rem;
            right: 1.5rem;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 0.875rem 1.5rem;
            border-radius: 50px;
            font-size: 0.9375rem;
            font-weight: 500;
            cursor: pointer;
            box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4);
            transition: all 0.2s ease;
            display: flex;
            align-items: center;
            gap: 0.5rem;
            z-index: 40;
          }
          .fyi-feedback-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(102, 126, 234, 0.5);
          }
          .fyi-feedback-overlay {
            position: fixed;
            inset: 0;
            background: rgba(0, 0, 0, 0.5);
            backdrop-filter: blur(4px);
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 50;
            animation: fadeIn 0.2s ease;
          }
          @keyframes fadeIn {
            from { opacity: 0; }
            to { opacity: 1; }
          }
          .fyi-feedback-modal {
            background: white;
            border-radius: 16px;
            width: 90%;
            max-width: 480px;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
            animation: slideUp 0.3s ease;
          }
          @keyframes slideUp {
            from { opacity: 0; transform: translateY(20px); }
            to { opacity: 1; transform: translateY(0); }
          }
          .fyi-feedback-header {
            padding: 1.5rem;
            border-bottom: 1px solid #e5e7eb;
            display: flex;
            justify-content: space-between;
            align-items: center;
          }
          .fyi-feedback-header h2 {
            font-size: 1.25rem;
            font-weight: 600;
            color: #111827;
            margin: 0;
          }
          .fyi-feedback-close {
            background: none;
            border: none;
            font-size: 1.5rem;
            color: #9ca3af;
            cursor: pointer;
            padding: 0.25rem;
            line-height: 1;
          }
          .fyi-feedback-close:hover {
            color: #6b7280;
          }
          .fyi-feedback-body {
            padding: 1.5rem;
          }
          .fyi-feedback-field {
            margin-bottom: 1.25rem;
          }
          .fyi-feedback-label {
            display: block;
            font-size: 0.875rem;
            font-weight: 500;
            color: #374151;
            margin-bottom: 0.5rem;
          }
          .fyi-feedback-input,
          .fyi-feedback-select,
          .fyi-feedback-textarea {
            width: 100%;
            padding: 0.75rem 1rem;
            border: 1px solid #d1d5db;
            border-radius: 8px;
            font-size: 0.9375rem;
            transition: border-color 0.15s, box-shadow 0.15s;
            box-sizing: border-box;
          }
          .fyi-feedback-input:focus,
          .fyi-feedback-select:focus,
          .fyi-feedback-textarea:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
          }
          .fyi-feedback-textarea {
            min-height: 120px;
            resize: vertical;
          }
          .fyi-feedback-submit {
            width: 100%;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 0.875rem;
            border-radius: 8px;
            font-size: 1rem;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.2s;
          }
          .fyi-feedback-submit:hover {
            opacity: 0.9;
          }
          .fyi-feedback-success {
            text-align: center;
            padding: 3rem 1.5rem;
          }
          .fyi-feedback-success-icon {
            font-size: 3rem;
            margin-bottom: 1rem;
          }
          .fyi-feedback-success h3 {
            font-size: 1.25rem;
            font-weight: 600;
            color: #111827;
            margin: 0 0 0.5rem;
          }
          .fyi-feedback-success p {
            color: #6b7280;
            margin: 0;
          }
        </style>

        <button type="button" class="fyi-feedback-btn" phx-click="open" phx-target={@myself}>
          <span>💬</span>
          <span>Feedback</span>
        </button>

        <%= if @show_modal do %>
          <div class="fyi-feedback-overlay" phx-click="close" phx-target={@myself}>
            <div class="fyi-feedback-modal" phx-click-away="close" phx-target={@myself}>
              <div class="fyi-feedback-header">
                <h2>Send Feedback</h2>
                <button class="fyi-feedback-close" phx-click="close" phx-target={@myself}>&times;</button>
              </div>

              <%= if @submitted do %>
                <div class="fyi-feedback-success">
                  <div class="fyi-feedback-success-icon">✅</div>
                  <h3>Thank you!</h3>
                  <p>Your feedback has been received.</p>
                </div>
              <% else %>
                <div class="fyi-feedback-body">
                  <form phx-submit="submit" phx-target={@myself}>
                    <div class="fyi-feedback-field">
                      <label class="fyi-feedback-label">Category</label>
                      <select name="category" class="fyi-feedback-select">
                        <option value="">Select a category...</option>
                        <option value="bug">Bug Report</option>
                        <option value="feature">Feature Request</option>
                        <option value="improvement">Improvement</option>
                        <option value="other">Other</option>
                      </select>
                    </div>

                    <div class="fyi-feedback-field">
                      <label class="fyi-feedback-label">Message *</label>
                      <textarea
                        name="message"
                        class="fyi-feedback-textarea"
                        placeholder="Tell us what's on your mind..."
                        required
                      ></textarea>
                    </div>

                    <div class="fyi-feedback-field">
                      <label class="fyi-feedback-label">Email (optional)</label>
                      <input
                        type="email"
                        name="email"
                        class="fyi-feedback-input"
                        placeholder="your@email.com"
                      />
                    </div>

                    <button type="submit" class="fyi-feedback-submit">
                      Send Feedback
                    </button>
                  </form>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
      """
    end
  end

  defmodule FYI.Web.FeedbackButton do
    @moduledoc """
    Convenience module for rendering the feedback button as a function component.

    ## Usage

        import FYI.Web.FeedbackButton

        <.fyi_feedback_button />
    """

    use Phoenix.Component

    @doc """
    Renders the FYI feedback button.
    """
    def fyi_feedback_button(assigns) do
      assigns = assign_new(assigns, :id, fn -> "fyi-feedback" end)

      ~H"""
      <.live_component module={FYI.Web.FeedbackComponent} id={@id} />
      """
    end
  end
end
