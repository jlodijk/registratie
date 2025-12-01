# lib/registratie_web/plugs/authorize_roles.ex
defmodule RegistratieWeb.Plugs.AuthorizeRole do
  import Plug.Conn
  import Phoenix.Controller
  use RegistratieWeb, :verified_routes

  def init(role), do: role

  def call(conn, required_role) do
    user = conn.assigns[:current_user]
    roles = extract_roles(user)

    if required_role in roles or "admin" in roles do
      conn
    else
      conn
      |> put_flash(:error, "Je hebt geen toegang tot deze pagina.")
      |> redirect(to: ~p"/home")
      |> halt()
    end
  end

  defp extract_roles(%{} = user) do
    cond do
      Map.has_key?(user, "roles") -> Map.get(user, "roles", [])
      Map.has_key?(user, :roles) -> Map.get(user, :roles, [])
      true -> []
    end
  end

  defp extract_roles(_), do: []
end
