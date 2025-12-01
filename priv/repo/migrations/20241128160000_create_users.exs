defmodule Registratie.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS citext;", "")

    create table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :utc_datetime_usec
      add :roles, {:array, :text}, null: false, default: []

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:users, [:email])
  end
end

