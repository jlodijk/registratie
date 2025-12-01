defmodule RegistratieWeb.HomeLive do
  use RegistratieWeb, :live_view

  def handle_event("logout", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Je bent uitgelogd.")
     |> redirect(to: ~p"/logout")}
  end

  def mount(_params, session, socket) do
    user = Map.get(session, "current_user")
    {:ok, assign(socket, current_user: user, page_title: "Home")}
  end

  def render(assigns) do
    ~H"""
    <h1>Welkom bij Registratie</h1>

    <%= if @current_user && @current_user["name"] do %>
      <div class="mt-4 flex flex-col items-center gap-5 text-center">
        <p class="flex items-center gap-3 text-lg font-semibold text-zinc-800">
          <.icon name="hero-user-circle-solid" class="h-6 w-6 text-blue-600" /> Je bent ingelogd als
          <span class="text-blue-700">{@current_user["name"]}</span>
          ({Enum.join(@current_user["roles"] || [], ", ")})
        </p>

        <div class="flex flex-col items-center gap-3 w-full max-w-xs">
          <%= if Enum.any?((@current_user["roles"] || []), &(&1 in ["begeleider", "admin"])) do %>
            <.link
              href={~p"/students/new"}
              class="inline-flex w-full items-center justify-center gap-2 rounded-lg border border-blue-600 bg-blue-600 px-5 py-3 text-sm font-semibold uppercase tracking-wide text-white transition hover:bg-white hover:text-blue-600"
            >
              <.icon name="hero-user-plus-solid" class="h-5 w-5" /> Nieuwe student
            </.link>
          <% end %>

          <%= if "studenten" in (@current_user["roles"] || []) do %>
            <.link
              href={~p"/profiel"}
              class="inline-flex w-full items-center justify-center gap-2 rounded-lg border border-slate-500 bg-white px-5 py-3 text-sm font-semibold uppercase tracking-wide text-slate-700 hover:bg-slate-100"
            >
              <.icon name="hero-pencil-square-solid" class="h-5 w-5" /> Mijn gegevens
            </.link>
          <% end %>

          <button
            phx-click="logout"
            class="inline-flex w-full items-center justify-center gap-2 rounded-lg border border-zinc-900 bg-zinc-900 px-5 py-3 text-sm font-semibold uppercase tracking-wide text-white transition hover:bg-white hover:text-zinc-900"
          >
            <.icon name="hero-arrow-right-on-rectangle-solid" class="h-5 w-5" /> Uitloggen
          </button>
        </div>
      </div>
    <% else %>
      <p>Je bent ingelogd als gast.</p>
    <% end %>
    """
  end
end
