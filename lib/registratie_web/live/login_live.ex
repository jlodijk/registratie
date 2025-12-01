defmodule RegistratieWeb.LoginLive do
  use RegistratieWeb, :live_view
  alias Registratie.Auth

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       username: "",
       password: "",
       # ← VOEG DIT TOE
       current_user: nil,
       page_title: "Inloggen"
     )}
  end

  def handle_event("login", %{"username" => username, "password" => password}, socket) do
    case Auth.authenticate(username, password) do
      {:ok, user_ctx} ->
        IO.inspect(user_ctx, label: "Authenticated user")

        {:noreply,
         socket
         |> assign(:current_user, user_ctx)
         |> put_flash(:info, "Welkom #{user_ctx["name"]}!")
         |> redirect(to: "/home")}

      {:error, :invalid_credentials} ->
        {:noreply,
         socket
         |> put_flash(:error, "Onjuiste gebruikersnaam of wachtwoord")
         |> assign(password: "")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Login mislukt: #{inspect(reason)}")
         |> assign(password: "")}
    end
  end

  def handle_event("logout", _value, socket) do
    {:noreply, push_navigate(socket, to: "/logout")}
  end

  def render(assigns) do
    ~H"""
    <div style="max-width: 400px; margin: 50px auto;">
      <h1>Inloggen</h1>

      <form phx-submit="login">
        <div style="margin-bottom: 1rem;">
          <label for="username">Gebruikersnaam:</label>
          <input
            type="text"
            name="username"
            id="username"
            value={@username}
            required
            style="width: 100%; padding: 8px;"
          />
        </div>

        <div style="margin-bottom: 1rem;">
          <label for="password">Wachtwoord:</label>
          <input
            type="password"
            name="password"
            id="password"
            value={@password}
            required
            style="width: 100%; padding: 8px;"
          />
        </div>

        <button
          type="submit"
          class="width: 100%; padding: 10px; background: rgb(0,102,204); color: white; border-style: solid;border-color: rgb(69 26 30);cursor: pointer;"
        >
          Inloggen
        </button>
      </form>
    </div>
    """
  end
end
