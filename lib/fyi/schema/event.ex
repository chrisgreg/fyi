if Code.ensure_loaded?(Ecto) do
  defmodule FYI.Schema.Event do
    @moduledoc """
    Ecto schema for persisted FYI events.

    This schema is used when `persist_events: true` is configured.
    """

    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :string, autogenerate: false}
    @timestamps_opts [type: :utc_datetime_usec, updated_at: false]

    schema "fyi_events" do
      field(:name, :string)
      field(:payload, :map, default: %{})
      field(:tags, :map, default: %{})
      field(:actor, :string)
      field(:source, :string)

      timestamps(inserted_at: :inserted_at)
    end

    @doc false
    def changeset(event, attrs) do
      event
      |> cast(attrs, [:id, :name, :payload, :tags, :actor, :source, :inserted_at])
      |> validate_required([:id, :name])
    end
  end
end
