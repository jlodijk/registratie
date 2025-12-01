defmodule Registratie.Repo do
  @moduledoc false
  use AshPostgres.Repo,
    otp_app: :registratie,
    warn_on_missing_ash_functions?: false

  def installed_extensions do
    ["citext"]
  end
end
