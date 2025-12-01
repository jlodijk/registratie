defmodule RegistratieWeb.UserAuth do
  @moduledoc """
  Handles user authentication for LiveView
  """
  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, _params, session, socket) do
    IO.inspect(session, label: "Session in UserAuth")

    case Map.get(session, "current_user") do
      nil ->
        {:halt,
         socket
         |> put_flash(:error, "Je moet ingelogd zijn")
         |> redirect(to: "/login")}

      user ->
        {:cont, assign(socket, current_user: user)}
    end
  end
end
