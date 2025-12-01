defmodule RegistratieWeb.AuthController do
  use RegistratieWeb, :controller
  alias Registratie.Auth

  def login(conn, %{"username" => username, "password" => password}) do
    case Auth.authenticate(username, password) do
      {:ok, user_ctx} ->
        conn
        |> put_session(:user, user_ctx)
        |> json(%{ok: true, user: user_ctx})

      {:error, :invalid_credentials} ->
        json(conn, %{ok: false, error: "Ongeldige inloggegevens"})
    end
  end

  def current_user(conn, _params) do
    user = get_session(conn, :user)
    json(conn, %{user: user})
  end
end
