# lib/registratie_web/plugs/fetch_current_user.ex
defmodule RegistratieWeb.Plugs.FetchCurrentUser do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    ash_user =
      conn.assigns[:current_user] ||
        conn.assigns[:current_user]

    session_user =
      get_session(conn, :current_user) ||
        get_session(conn, :user)

    assign(conn, :current_user, ash_user || session_user)
  end
end
