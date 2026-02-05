defmodule Registratie.Repo do
  @moduledoc false
  use AshPostgres.Repo,
    otp_app: :registratie,
    warn_on_missing_ash_functions?: false

  def installed_extensions do
    ["citext"]
  end

  # Declare the minimum supported Postgres version for migrations/runtime checks.
  def min_pg_version do
    %Version{major: 16, minor: 0, patch: 0}
  end
end
