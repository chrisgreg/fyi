defmodule FYI.Event do
  @moduledoc """
  Represents an event in the FYI system.

  An event has:
  - `name` - dot-separated event name (e.g., "purchase.created")
  - `payload` - arbitrary map of event data
  - `actor` - who/what triggered the event (user_id, system, etc.)
  - `tags` - additional metadata for filtering/routing
  - `source` - where the event originated
  - `occurred_at` - when the event happened
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t(),
          payload: map(),
          actor: String.t() | nil,
          tags: map(),
          source: String.t() | nil,
          emoji: String.t() | nil,
          occurred_at: DateTime.t()
        }

  @derive Jason.Encoder
  defstruct [
    :id,
    :name,
    :actor,
    :source,
    :emoji,
    payload: %{},
    tags: %{},
    occurred_at: nil
  ]

  @doc """
  Creates a new event with the given name and payload.

  ## Options

  - `:actor` - who triggered the event (user_id, email, etc.)
  - `:tags` - additional metadata map
  - `:source` - where the event originated
  - `:emoji` - override emoji for this specific event

  ## Examples

      iex> FYI.Event.new("purchase.created", %{amount: 4900})
      %FYI.Event{name: "purchase.created", payload: %{amount: 4900}, ...}

      iex> FYI.Event.new("user.signup", %{email: "user@example.com"}, actor: "user_123")
      %FYI.Event{name: "user.signup", actor: "user_123", ...}

      iex> FYI.Event.new("error.critical", %{}, emoji: "🚨")
      %FYI.Event{name: "error.critical", emoji: "🚨", ...}
  """
  @spec new(String.t(), map(), keyword()) :: t()
  def new(name, payload \\ %{}, opts \\ []) when is_binary(name) and is_map(payload) do
    %__MODULE__{
      id: generate_id(),
      name: name,
      payload: payload,
      actor: to_string_or_nil(opts[:actor]),
      tags: opts[:tags] || %{},
      source: opts[:source],
      emoji: opts[:emoji],
      occurred_at: DateTime.utc_now()
    }
  end

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp to_string_or_nil(nil), do: nil
  defp to_string_or_nil(value), do: to_string(value)
end
