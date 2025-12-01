defmodule RegistratieWeb.AuthPlug do
  @moduledoc false
  use AshAuthentication.Plug, otp_app: :registratie

  import Plug.Conn
  import Phoenix.Controller

  @impl true
  def handle_success(conn, _activity, user, _token) do
    conn
    |> store_in_session(user)
    |> put_session(:current_user, user) # keep legacy session key for existing plugs
    |> put_flash(:info, "Ingelogd.")
    |> redirect(to: "/home")
    |> halt()
  end

  @impl true
  def handle_failure(conn, _activity, _reason) do
    conn
    |> put_flash(:error, "Inloggen mislukt.")
    |> redirect(to: "/login")
    |> halt()
  end
end

