defmodule Registratie.Accounts.User do
  @moduledoc """
  Ash resource voor gebruikersauthenticatie via Postgres.
  """
  use Ash.Resource,
    domain: Registratie.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "users"
    repo Registratie.Repo
  end

  authentication do
    # We don't store JTI per-session; tokens will be considered valid even after logout.
    session_identifier :unsafe

    strategies do
      password :password do
        identity_field :email
        hashed_password_field :hashed_password
        confirmation_required? false
        sign_in_tokens_enabled? false
      end
    end
  end

  identities do
    identity :unique_email, [:email]
  end

  attributes do
    uuid_primary_key :id
    attribute :email, :ci_string, allow_nil?: false, public?: true
    attribute :hashed_password, :string, allow_nil?: false, sensitive?: true
    attribute :confirmed_at, :utc_datetime_usec
    attribute :roles, {:array, :string}, default: [], allow_nil?: false, public?: true
  end

  actions do
    defaults [:read, :create, :update, :destroy]
  end

  policies do
    policy action(:create) do
      authorize_if always()
    end

    policy action([:read, :update, :destroy]) do
      authorize_if expr(id == ^actor(:id))
      forbid_if always()
    end
  end
end
