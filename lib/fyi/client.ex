defmodule FYI.Client do
  @moduledoc """
  Centralized HTTP client for FYI sinks.

  Provides a configured Req client with:
  - Automatic retries for transient failures (network errors, 5xx responses)
  - Exponential backoff (1s, 2s, 4s)
  - Connection pooling via Finch
  - Respect for Retry-After headers

  ## Configuration

  By default, the client will:
  - Retry transient failures (network errors, 500-599 status codes) up to 3 times
  - Use exponential backoff: 1s, 2s, 4s
  - Honor Retry-After response headers

  You can customize retry behavior in your config:

      config :fyi,
        http_client: [
          max_retries: 5,
          retry_delay: fn attempt -> attempt * 2000 end
        ]

  Set `max_retries: 0` to disable retries entirely.

  ## Examples

      # Simple POST request
      FYI.Client.post("https://api.example.com/webhook", json: %{text: "Hello"})
      #=> {:ok, %Req.Response{status: 200, ...}}

      # With custom options
      FYI.Client.post(
        "https://api.example.com/webhook",
        json: %{text: "Hello"},
        headers: [{"authorization", "Bearer token"}]
      )
  """

  @doc """
  Creates a new configured Req client.

  The client includes retry logic and connection pooling.
  """
  @spec new(keyword()) :: Req.Request.t()
  def new(opts \\ []) do
    config = Application.get_env(:fyi, :http_client, [])
    max_retries = Keyword.get(config, :max_retries, 3)
    retry_delay = Keyword.get(config, :retry_delay, &default_retry_delay/1)

    base_opts = [
      retry: :transient,
      max_retries: max_retries,
      retry_delay: retry_delay
    ]

    Req.new(Keyword.merge(base_opts, opts))
  end

  @doc """
  Makes a POST request using the configured client.

  Returns `{:ok, response}` or `{:error, exception}`.

  ## Options

  All standard Req options are supported. Common ones:
  - `:json` - Request body as JSON
  - `:headers` - List of header tuples
  - `:receive_timeout` - Request timeout in milliseconds

  ## Examples

      FYI.Client.post("https://hooks.slack.com/...", json: %{text: "Hello"})
      #=> {:ok, %Req.Response{status: 200, body: "ok"}}

      FYI.Client.post("https://api.telegram.org/bot.../sendMessage", json: %{
        chat_id: "123",
        text: "Hello"
      })
      #=> {:ok, %Req.Response{status: 200, body: %{"ok" => true}}}
  """
  @spec post(String.t(), keyword()) :: {:ok, Req.Response.t()} | {:error, Exception.t()}
  def post(url, opts \\ []) do
    client = new()
    Req.post(client, Keyword.put(opts, :url, url))
  end

  # Default exponential backoff: 1s, 2s, 4s
  defp default_retry_delay(attempt) do
    Integer.pow(2, attempt - 1) * 1000
  end
end
