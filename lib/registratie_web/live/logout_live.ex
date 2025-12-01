defmodule RegistratieWeb.LogoutLive do
  use RegistratieWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_user, nil)
     |> put_flash(:info, "Je bent uitgelogd")
     |> redirect(to: "/login")}
  end
end
