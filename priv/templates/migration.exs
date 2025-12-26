defmodule <%= @repo %>.Migrations.CreateFyiEvents do
  use Ecto.Migration

  def change do
    create table(:fyi_events, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :payload, :map, default: %{}
      add :tags, :map, default: %{}
      add :actor, :string
      add :source, :string

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create index(:fyi_events, [:name])
    create index(:fyi_events, [:actor])
    create index(:fyi_events, [:inserted_at])
  end
end
