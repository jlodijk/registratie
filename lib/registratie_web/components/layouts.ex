defmodule RegistratieWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use RegistratieWeb, :controller` and
  `use RegistratieWeb, :live_view`.
  """
  use RegistratieWeb, :html

  embed_templates "layouts/*"

  attr :current_user, :any, default: nil
  attr :compact_header?, :boolean, default: false

  def asha_brand_row(assigns) do
    ~H"""
    <header class="relative z-30 isolate border-b border-white/60 bg-white/80 shadow-sm backdrop-blur">
      <%= if @compact_header? do %>
        <div class="mx-auto flex max-w-6xl items-center justify-between px-4 py-4 sm:px-6 lg:px-8">
          <a href="/" class="flex items-center">
            <img
              src={~p"/images/stichting-asha-logo.svg"}
              width="190"
              alt="Stichting Asha"
              class="h-auto"
            />
          </a>

          <div class="flex items-center gap-3 text-base font-semibold leading-6 text-zinc-900">
            <.link href={~p"/contact"} class="hover:text-zinc-700 inline-flex items-center gap-2">
              <.icon name="hero-phone-arrow-up-right" class="h-4 w-4" />
              Contact
            </.link>
            <.link
              href={~p"/login"}
              class="bg-blue-600 text-white font-semibold rounded-full px-5 py-2 border-2 border-[#FB923C] shadow-md hover:bg-blue-700 hover:shadow-lg transition"
            >
              Login
            </.link>
          </div>
        </div>
      <% else %>
      <div aria-hidden="true" class="pointer-events-none absolute inset-y-0 right-[-5%] hidden w-1/2 rotate-6 bg-gradient-to-br from-[#FDBA74]/50 via-[#FB923C]/30 to-[#0EA5E9]/30 blur-2xl sm:block -z-10"></div>
      <div aria-hidden="true" class="pointer-events-none absolute inset-y-0 left-[-10%] w-1/3 -rotate-6 bg-gradient-to-br from-[#0EA5E9]/40 via-[#38BDF8]/20 to-transparent blur-3xl -z-10"></div>
      <div class="mx-auto flex max-w-6xl flex-col gap-4 px-4 py-4 sm:px-6 lg:px-8">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div class="flex items-center gap-6">
            <a href="/" class="flex items-center">
              <img
                src={~p"/images/stichting-asha-logo.svg"}
                width="190"
                alt="Stichting Asha"
                class="h-auto"
              />
            </a>

            <nav class="hidden md:flex items-center gap-6 text-base font-semibold leading-6 text-zinc-900">
              <.link href={~p"/home"} class="hover:text-zinc-700 inline-flex items-center gap-2">
                <.icon name="hero-home" class="h-4 w-4" />
                Home
              </.link>
              <%= if can_manage_students?(@current_user) do %>
                <div class="relative z-10 group">
                  <button
                    type="button"
                    class="inline-flex items-center gap-2 rounded-full border border-transparent px-3 py-1 text-base font-semibold text-zinc-900 transition group-hover:text-blue-600"
                  >
                    <.icon name="hero-academic-cap" class="h-4 w-4" />
                    Studenten
                    <.icon name="hero-chevron-down" class="h-4 w-4" />
                  </button>
                  <div class="absolute left-0 top-full z-20 mt-1 hidden w-[22rem] flex-col rounded-2xl bg-white p-4 text-sm text-zinc-700 shadow-xl ring-1 ring-black/5 group-hover:flex group-focus-within:flex">
                    <p class="flex items-center gap-2 px-1 text-xs font-semibold uppercase tracking-[0.2em] text-zinc-400">
                      <.icon name="hero-clipboard-document-check" class="h-3 w-3" />
                      Beheer
                    </p>
                    <div class="mt-3 grid grid-cols-1 gap-3">
                      <.link
                        href={~p"/students/new"}
                        class="flex flex-col gap-1 rounded-xl border border-zinc-100 bg-zinc-50 px-4 py-3 shadow-sm transition hover:border-blue-200 hover:bg-white"
                      >
                        <span class="inline-flex items-center gap-2 text-base font-semibold text-zinc-900">
                          <.icon name="hero-user-plus" class="h-4 w-4" />
                          Nieuwe student
                        </span>
                        <span class="text-xs text-zinc-500">
                          Voeg een nieuwe student toe en maak direct een account aan.
                        </span>
                      </.link>
                      <.link
                        href={~p"/password/reset"}
                        class="flex flex-col gap-1 rounded-xl border border-zinc-100 bg-zinc-50 px-4 py-3 shadow-sm transition hover:border-blue-200 hover:bg-white"
                      >
                        <span class="inline-flex items-center gap-2 text-base font-semibold text-zinc-900">
                          <.icon name="hero-key" class="h-4 w-4" />
                          Wachtwoord resetten
                        </span>
                        <span class="text-xs text-zinc-500">
                          Geef een student tijdelijk toegang met een nieuw wachtwoord.
                        </span>
                      </.link>
                      <.link
                        href={~p"/attendance"}
                        class="flex flex-col gap-1 rounded-xl border border-zinc-100 bg-zinc-50 px-4 py-3 shadow-sm transition hover:border-blue-200 hover:bg-white"
                      >
                        <span class="inline-flex items-center gap-2 text-base font-semibold text-zinc-900">
                          <.icon name="hero-clipboard-document-list" class="h-4 w-4" />
                          Aanwezigheid
                        </span>
                        <span class="text-xs text-zinc-500">
                          Bekijk login- en uitlogtijden per student.
                        </span>
                      </.link>
                      <.link
                        href={~p"/contactpersonen"}
                        class="flex flex-col gap-1 rounded-xl border border-zinc-100 bg-zinc-50 px-4 py-3 shadow-sm transition hover:border-blue-200 hover:bg-white"
                      >
                        <span class="inline-flex items-center gap-2 text-base font-semibold text-zinc-900">
                          <.icon name="hero-briefcase" class="h-4 w-4" />
                          Contactpersonen scholen
                        </span>
                        <span class="text-xs text-zinc-500">
                          Beheer de schoolcontacten per opleiding.
                        </span>
                      </.link>
                      <.link
                        href={~p"/taken"}
                        class="flex flex-col gap-1 rounded-xl border border-zinc-100 bg-zinc-50 px-4 py-3 shadow-sm transition hover:border-blue-200 hover:bg-white"
                      >
                        <span class="inline-flex items-center gap-2 text-base font-semibold text-zinc-900">
                          <.icon name="hero-check-badge" class="h-4 w-4" />
                          Taken
                        </span>
                        <span class="text-xs text-zinc-500">
                          Ken taken toe aan studenten en volg de status.
                        </span>
                      </.link>
                      <.link
                        href={~p"/studenten/overzicht"}
                        class="flex flex-col gap-1 rounded-xl border border-zinc-100 bg-zinc-50 px-4 py-3 shadow-sm transition hover:border-blue-200 hover:bg-white"
                      >
                        <span class="inline-flex items-center gap-2 text-base font-semibold text-zinc-900">
                          <.icon name="hero-user-circle" class="h-4 w-4" />
                          Studentoverzicht
                        </span>
                        <span class="text-xs text-zinc-500">
                          Bekijk alle gegevens van een student.
                        </span>
                      </.link>
                    </div>
                  </div>
                </div>
                <div class="relative z-10 group">
                  <button
                    type="button"
                    class="inline-flex items-center gap-2 rounded-full border border-transparent px-3 py-1 text-base font-semibold text-zinc-900 transition group-hover:text-blue-600"
                  >
                    <.icon name="hero-check-badge" class="h-4 w-4" />
                    Taken
                    <.icon name="hero-chevron-down" class="h-4 w-4" />
                  </button>
                  <div class="absolute left-0 top-full z-20 mt-1 hidden w-[18rem] flex-col rounded-2xl bg-white p-4 text-sm text-zinc-700 shadow-xl ring-1 ring-black/5 group-hover:flex group-focus-within:flex">
                    <p class="flex items-center gap-2 px-1 text-xs font-semibold uppercase tracking-[0.2em] text-zinc-400">
                      <.icon name="hero-clipboard-document-list" class="h-3 w-3" />
                      Taken
                    </p>
                    <div class="mt-3 grid grid-cols-1 gap-3">
                      <.link
                        href={~p"/taken"}
                        class="flex flex-col gap-1 rounded-xl border border-zinc-100 bg-zinc-50 px-4 py-3 shadow-sm transition hover:border-blue-200 hover:bg-white"
                      >
                        <span class="inline-flex items-center gap-2 text-base font-semibold text-zinc-900">
                          <.icon name="hero-check-badge" class="h-4 w-4" />
                          Taken beheren
                        </span>
                        <span class="text-xs text-zinc-500">
                          Taken toewijzen en statussen bijwerken.
                        </span>
                      </.link>
                      <.link
                        href={~p"/standaard-taken"}
                        class="flex flex-col gap-1 rounded-xl border border-zinc-100 bg-zinc-50 px-4 py-3 shadow-sm transition hover:border-blue-200 hover:bg-white"
                      >
                        <span class="inline-flex items-center gap-2 text-base font-semibold text-zinc-900">
                          <.icon name="hero-clipboard-document-list" class="h-4 w-4" />
                          Standaard taken
                        </span>
                        <span class="text-xs text-zinc-500">
                          Beheer de suggestielijst.
                        </span>
                      </.link>
                    </div>
                  </div>
                </div>
              <% end %>
              <%= if admin?(@current_user) do %>
                <div class="relative group">
                  <button
                    type="button"
                    class="inline-flex items-center gap-2 rounded-full border border-transparent px-3 py-1 text-base font-semibold text-zinc-900 transition group-hover:text-blue-600"
                  >
                    <.icon name="hero-cpu-chip" class="h-4 w-4" />
                    Devices
                    <.icon name="hero-chevron-down" class="h-4 w-4" />
                  </button>
                  <div class="absolute left-0 top-full z-20 mt-1 hidden w-[22rem] flex-col rounded-2xl bg-white p-4 text-sm text-zinc-700 shadow-xl ring-1 ring-black/5 group-hover:flex group-focus-within:flex">
                    <p class="flex items-center gap-2 px-1 text-xs font-semibold uppercase tracking-[0.2em] text-zinc-400">
                      <.icon name="hero-wrench" class="h-3 w-3" />
                      Apparaten
                    </p>
                    <div class="mt-3 grid grid-cols-1 gap-3">
                      <.link
                        href={~p"/bbsids"}
                        class="flex flex-col gap-1 rounded-xl border border-zinc-100 bg-zinc-50 px-4 py-3 shadow-sm transition hover:border-blue-200 hover:bg-white"
                      >
                        <span class="inline-flex items-center gap-2 text-base font-semibold text-zinc-900">
                          <.icon name="hero-wifi" class="h-4 w-4" />
                          BSSID beheer
                        </span>
                        <span class="text-xs text-zinc-500">
                          Voer toegestane wifi-locaties in of verwijder ze.
                        </span>
                      </.link>
                    </div>
                  </div>
                </div>
              <% end %>
              <%= if bol2_student?(@current_user) and not can_manage_students?(@current_user) do %>
                <.link href={~p"/devices"} class="hover:text-zinc-700 inline-flex items-center gap-2">
                  <.icon name="hero-cpu-chip" class="h-4 w-4" />
                  Devices
                </.link>
                <.link href={~p"/network"} class="hover:text-zinc-700 inline-flex items-center gap-2">
                  <.icon name="hero-rss" class="h-4 w-4" />
                  Netwerk
                </.link>
              <% end %>
              <%= if can_view_progress?(@current_user) do %>
                <.link href={~p"/progress"} class="hover:text-zinc-700 inline-flex items-center gap-2">
                  <.icon name="hero-chart-bar" class="h-4 w-4" />
                  Voortgang
                </.link>
              <% end %>
              <%= if can_access_help_requests?(@current_user) do %>
                <.link href={help_requests_path(@current_user)} class="hover:text-zinc-700 inline-flex items-center gap-2">
                  <.icon name="hero-chat-bubble-left-right" class="h-4 w-4" />
                  Hulpvragen
                </.link>
              <% end %>
              <%= if can_access_mission?(@current_user) do %>
                <.link href={mission_path(@current_user)} class="hover:text-zinc-700 inline-flex items-center gap-2">
                  <.icon name="hero-rocket-launch" class="h-4 w-4" />
                  Missie
                </.link>
              <% end %>
              <.link href={~p"/contact"} class="hover:text-zinc-700 inline-flex items-center gap-2">
                <.icon name="hero-phone-arrow-up-right" class="h-4 w-4" />
                Contact
              </.link>
            </nav>
          </div>

          <div class="flex items-center gap-4 text-base font-semibold leading-6 text-zinc-900">
            <%= if @current_user do %>
              <.link href={~p"/logout"} method="delete" class="hover:text-zinc-700 inline-flex items-center gap-2">
                <.icon name="hero-arrow-left-on-rectangle" class="h-4 w-4" />
                Uitloggen
              </.link>
            <% else %>
              <div class="flex items-center gap-2">
                <.link
                  href={~p"/login"}
                  class="bg-blue-600 text-white font-semibold rounded-full px-6 py-2 border-2 border-[#FB923C] shadow-md hover:bg-blue-700 hover:shadow-lg transition"
                >
                  Login
                </.link>

                <.link
                  href={~p"/register"}
                  class="bg-green-600 text-white font-semibold rounded-full px-6 py-2 border-2 border-[#FB923C] shadow-md hover:bg-green-700 hover:shadow-lg transition"
                >
                  Register
                </.link>
              </div>
            <% end %>
          </div>

          <button class="inline-flex items-center gap-2 rounded-full border border-[#FB923C] px-4 py-2 text-sm font-semibold text-zinc-800 shadow-sm transition hover:bg-orange-50 md:hidden">
            Menu
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-4 w-4"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
            >
              <path d="M4 6h16M4 12h16M4 18h16" stroke-linecap="round" stroke-linejoin="round" />
            </svg>
          </button>
        </div>

        <nav class="flex flex-col items-center gap-4 text-base font-semibold text-zinc-900 md:hidden">
          <.link href={~p"/home"} class="hover:text-zinc-700 inline-flex items-center gap-2">
            <.icon name="hero-home" class="h-4 w-4" />
            Home
          </.link>
          <%= if can_manage_students?(@current_user) do %>
            <div class="w-full rounded-2xl border border-zinc-200 bg-white p-4 text-left shadow-sm">
              <p class="text-xs font-semibold uppercase tracking-[0.2em] text-zinc-400">Studenten</p>
              <div class="mt-3 flex flex-col gap-3 text-sm">
                <.link
                  href={~p"/students/new"}
                  class="rounded-xl border border-zinc-100 bg-zinc-50 px-4 py-3 text-zinc-800 shadow-sm hover:border-blue-200 hover:bg-white"
                >
                  <span class="inline-flex items-center gap-2">
                    <.icon name="hero-user-plus" class="h-4 w-4" />
                    Nieuwe student
                  </span>
                  <p class="text-xs text-zinc-500">
                    Maak een nieuw account aan.
                  </p>
                </.link>
                <.link
                  href={~p"/password/reset"}
                  class="rounded-xl border border-zinc-100 bg-zinc-50 px-4 py-3 text-zinc-800 shadow-sm hover:border-blue-200 hover:bg-white"
                >
                  <span class="inline-flex items-center gap-2">
                    <.icon name="hero-key" class="h-4 w-4" />
                    Wachtwoord resetten
                  </span>
                  <p class="text-xs text-zinc-500">
                    Verstrek een tijdelijk wachtwoord.
                  </p>
                </.link>
                <.link
                  href={~p"/attendance"}
                  class="rounded-xl border border-zinc-100 bg-zinc-50 px-4 py-3 text-zinc-800 shadow-sm hover:border-blue-200 hover:bg-white"
                >
                  <span class="inline-flex items-center gap-2">
                    <.icon name="hero-clipboard-document-list" class="h-4 w-4" />
                    Aanwezigheid
                  </span>
                  <p class="text-xs text-zinc-500">
                    Bekijk login- en uitlogtijden per student.
                  </p>
                </.link>
                <.link
                  href={~p"/contactpersonen"}
                  class="rounded-xl border border-zinc-100 bg-zinc-50 px-4 py-3 text-zinc-800 shadow-sm hover:border-blue-200 hover:bg-white"
                >
                  <span class="inline-flex items-center gap-2">
                    <.icon name="hero-briefcase" class="h-4 w-4" />
                    Contactpersonen scholen
                  </span>
                  <p class="text-xs text-zinc-500">
                    Beheer de schoolcontacten per opleiding.
                  </p>
                </.link>
                <.link
                  href={~p"/taken"}
                  class="rounded-xl border border-zinc-100 bg-zinc-50 px-4 py-3 text-zinc-800 shadow-sm hover:border-blue-200 hover:bg-white"
                >
                  <span class="inline-flex items-center gap-2">
                    <.icon name="hero-check-badge" class="h-4 w-4" />
                    Taken
                  </span>
                  <p class="text-xs text-zinc-500">
                    Taken per student beheren.
                  </p>
                </.link>
                <.link
                  href={~p"/studenten/overzicht"}
                  class="rounded-xl border border-zinc-100 bg-zinc-50 px-4 py-3 text-zinc-800 shadow-sm hover:border-blue-200 hover:bg-white"
                >
                  <span class="inline-flex items-center gap-2">
                    <.icon name="hero-user-circle" class="h-4 w-4" />
                    Studentoverzicht
                  </span>
                  <p class="text-xs text-zinc-500">
                    Bekijk alle gegevens van een student.
                  </p>
                </.link>
              </div>
            </div>
            <div class="w-full rounded-2xl border border-zinc-200 bg-white p-4 text-left shadow-sm">
              <p class="text-xs font-semibold uppercase tracking-[0.2em] text-zinc-400 inline-flex items-center gap-2">
                <.icon name="hero-clipboard-document-list" class="h-4 w-4" />
                Taken
              </p>
              <div class="mt-3 flex flex-col gap-3 text-sm">
                <.link
                  href={~p"/taken"}
                  class="rounded-xl border border-zinc-100 bg-zinc-50 px-4 py-3 text-zinc-800 shadow-sm hover:border-blue-200 hover:bg-white"
                >
                  <span class="inline-flex items-center gap-2">
                    <.icon name="hero-check-badge" class="h-4 w-4" />
                    Taken beheren
                  </span>
                  <p class="text-xs text-zinc-500">
                    Taken toewijzen en statussen updaten.
                  </p>
                </.link>
                <.link
                  href={~p"/standaard-taken"}
                  class="rounded-xl border border-zinc-100 bg-zinc-50 px-4 py-3 text-zinc-800 shadow-sm hover:border-blue-200 hover:bg-white"
                >
                  <span class="inline-flex items-center gap-2">
                    <.icon name="hero-clipboard-document-list" class="h-4 w-4" />
                    Standaard taken
                  </span>
                  <p class="text-xs text-zinc-500">
                    Beheer de suggestielijst.
                  </p>
                </.link>
              </div>
            </div>
          <% end %>
          <%= if bol2_student?(@current_user) and not can_manage_students?(@current_user) do %>
            <.link href={~p"/devices"} class="hover:text-zinc-700 inline-flex items-center gap-2">
              <.icon name="hero-cpu-chip" class="h-4 w-4" />
              Devices
            </.link>
            <.link href={~p"/network"} class="hover:text-zinc-700 inline-flex items-center gap-2">
              <.icon name="hero-rss" class="h-4 w-4" />
              Netwerk
            </.link>
          <% end %>
          <%= if can_view_progress?(@current_user) do %>
            <.link href={~p"/progress"} class="hover:text-zinc-700 inline-flex items-center gap-2">
              <.icon name="hero-chart-bar" class="h-4 w-4" />
              Voortgang
            </.link>
          <% end %>
          <%= if can_access_help_requests?(@current_user) do %>
            <.link href={help_requests_path(@current_user)} class="hover:text-zinc-700 inline-flex items-center gap-2">
              <.icon name="hero-chat-bubble-left-right" class="h-4 w-4" />
              Hulpvragen
            </.link>
          <% end %>
          <%= if can_access_mission?(@current_user) do %>
            <.link href={mission_path(@current_user)} class="hover:text-zinc-700 inline-flex items-center gap-2">
              <.icon name="hero-rocket-launch" class="h-4 w-4" />
              Missie
            </.link>
          <% end %>
          <%= if admin?(@current_user) do %>
            <div class="w-full rounded-2xl border border-zinc-200 bg-white p-4 text-left shadow-sm">
              <p class="text-xs font-semibold uppercase tracking-[0.2em] text-zinc-400 inline-flex items-center gap-2"><.icon name="hero-cpu-chip" class="h-4 w-4" />Devices</p>
              <div class="mt-3 flex flex-col gap-3 text-sm">
                <.link
                  href={~p"/bbsids"}
                  class="rounded-xl border border-zinc-100 bg-zinc-50 px-4 py-3 text-zinc-800 shadow-sm hover:border-blue-200 hover:bg-white"
                >
                  <span class="inline-flex items-center gap-2">
                    <.icon name="hero-wifi" class="h-4 w-4" />
                    BSSID beheer
                  </span>
                  <p class="text-xs text-zinc-500">
                    Beheer toegestane wifi-locaties.
                  </p>
                </.link>
              </div>
            </div>
          <% end %>
          <.link href={~p"/contact"} class="hover:text-zinc-700 inline-flex items-center gap-2">
            <.icon name="hero-phone-arrow-up-right" class="h-4 w-4" />
            Contact
          </.link>
        </nav>
      </div>
      <% end %>
    </header>
    """
  end

  defp can_manage_students?(user) do
    has_role?(user, "begeleider") || has_role?(user, "admin")
  end

  defp admin?(user), do: has_role?(user, "admin")

  defp can_view_progress?(user) do
    has_role?(user, "begeleider") || admin?(user)
  end

  defp can_access_help_requests?(user) do
    has_role?(user, "studenten") || has_role?(user, "begeleider") || admin?(user)
  end

  defp help_requests_path(user) do
    if has_role?(user, "begeleider") || admin?(user) do
      ~p"/hulpvragen/overzicht"
    else
      ~p"/hulpvragen"
    end
  end

  defp can_access_mission?(user) do
    has_role?(user, "studenten") || has_role?(user, "begeleider") || admin?(user)
  end

  defp mission_path(user) do
    if has_role?(user, "begeleider") || admin?(user) do
      ~p"/missie/overzicht"
    else
      ~p"/missie"
    end
  end

  defp bol2_student?(nil), do: false

  defp bol2_student?(user) do
    opleiding =
      Map.get(user, "opleiding") ||
        Map.get(user, :opleiding) ||
        ""

    opleiding
    |> to_string()
    |> String.downcase()
    |> String.contains?("bol 2")
  end

  defp has_role?(%{} = user, role) do
    roles =
      cond do
        Map.has_key?(user, "roles") -> Map.get(user, "roles", [])
        Map.has_key?(user, :roles) -> Map.get(user, :roles, [])
        true -> []
      end

    role in roles
  end

  defp has_role?(_, _), do: false
end
