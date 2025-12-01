defmodule Registratie.Accounts do
  @moduledoc false
  use Ash.Domain

  resources do
    resource Registratie.Accounts.User
  end
end

