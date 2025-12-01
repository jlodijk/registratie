defmodule RegistratieWeb.Plugs.RequireAuthenticatedUser do
  use RegistratieWeb, :verified_routes
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:current_user] || get_session(conn, :current_user) do
      conn
    else
      conn
      |> put_flash(:error, "Log eerst in om deze pagina te bekijken.")
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end
end
