defmodule RegistratieWeb.RegisterController do
  use RegistratieWeb, :controller
  alias Registratie.Auth

  def new(conn, _params) do
    render(conn, :new, page_title: "Registreren")
  end

  def create(conn, %{"username" => username, "password" => password}) do
    case Auth.register(username, password) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Gebruiker #{user["name"]} aangemaakt.")
        |> redirect(to: ~p"/login")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Registratie mislukt: #{inspect(reason)}")
        |> redirect(to: ~p"/register")
    end
  end
end
