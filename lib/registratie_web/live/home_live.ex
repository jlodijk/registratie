defmodule RegistratieWeb.HomeLive do
  use RegistratieWeb, :live_view

  def mount(_params, session, socket) do
    user = Map.get(session, "current_user")
    compact? = is_nil(user)
    {:ok, assign(socket, current_user: user, page_title: "Home", compact_header?: compact?)}
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
          <%= if "studenten" in (@current_user["roles"] || []) do %>
            <.link
              href={~p"/profiel"}
              class="inline-flex w-full items-center justify-center gap-2 rounded-lg border border-slate-500 bg-white px-5 py-3 text-sm font-semibold uppercase tracking-wide text-slate-700 hover:bg-slate-100"
            >
              <.icon name="hero-pencil-square-solid" class="h-5 w-5" /> Mijn gegevens
            </.link>
            <.link
              href={~p"/mijn-uren"}
              class="inline-flex w-full items-center justify-center gap-2 rounded-lg border border-emerald-500 bg-emerald-50 px-5 py-3 text-sm font-semibold uppercase tracking-wide text-emerald-800 hover:bg-emerald-100"
            >
              <.icon name="hero-clock-solid" class="h-5 w-5" /> Behaalde uren
            </.link>
          <% end %>

          <.link
            href={~p"/logout"}
            class="inline-flex w-full items-center justify-center gap-2 rounded-lg border border-zinc-900 bg-zinc-900 px-5 py-3 text-sm font-semibold uppercase tracking-wide text-white transition hover:bg-white hover:text-zinc-900"
          >
            <.icon name="hero-arrow-right-on-rectangle-solid" class="h-5 w-5" /> Uitloggen
          </.link>
        </div>
      </div>
    <% else %>
      <p>Je bent ingelogd als gast.</p>
    <% end %>
    """
  end
end
