defmodule RegistratieWeb.MyHoursLive do
  use RegistratieWeb, :live_view

  alias Registratie.AttendanceReport

  @impl true
  def mount(_params, session, socket) do
    current_user = Map.get(session, "current_user") || %{}

    cond do
      current_user == %{} ->
        {:ok,
         socket
         |> put_flash(:error, "Log in om je uren te bekijken.")
         |> redirect(to: ~p"/login")}

      not student?(current_user) ->
        {:ok,
         socket
         |> put_flash(:error, "Alleen studenten kunnen behaalde uren bekijken.")
         |> redirect(to: ~p"/home")}

      true ->
        case AttendanceReport.generate(current_user["name"]) do
          {:ok, report} ->
            {:ok,
             assign(socket,
               current_user: current_user,
               page_title: "Behaalde uren",
               rows: report.rows,
               total_label: format_total(report.total_hours)
             )}

          {:error, reason} ->
            {:ok,
             socket
             |> put_flash(:error, "Kon uren niet ophalen: #{reason}")
             |> assign(rows: [], total_label: "0,0" , current_user: current_user, page_title: "Behaalde uren")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <p class="text-sm uppercase tracking-wide text-zinc-500">Mijn gegevens</p>
          <h1 class="text-2xl font-bold text-zinc-900">Behaalde uren</h1>
          <p class="text-sm text-zinc-600">Overzicht van je geregistreerde aanwezigheid.</p>
        </div>
        <.link href={~p"/home"} class="text-sm text-blue-700 hover:underline">Terug naar home</.link>
      </div>

      <div class="overflow-hidden rounded-2xl border border-zinc-200 shadow-sm bg-white">
        <table class="min-w-full divide-y divide-zinc-200">
          <thead class="bg-zinc-50 text-left text-xs font-semibold uppercase tracking-wide text-zinc-600">
            <tr>
              <th class="px-4 py-3">Datum</th>
              <th class="px-4 py-3">Dag</th>
              <th class="px-4 py-3">Uren</th>
              <th class="px-4 py-3">Opmerking</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-zinc-100 text-sm text-zinc-800">
            <tr :if={@rows == []}>
              <td colspan="4" class="px-4 py-4 text-center text-zinc-500">Geen aanwezigheid gevonden.</td>
            </tr>

            <tr :for={row <- @rows}>
              <td class="px-4 py-3 font-medium">{row.date_label}</td>
              <td class="px-4 py-3 text-zinc-600">{row.weekday}</td>
              <td class="px-4 py-3 font-semibold">{row.hours_label}</td>
              <td class="px-4 py-3 text-zinc-600">{row.message || ""}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="flex items-center justify-between rounded-xl border border-zinc-200 bg-zinc-50 px-4 py-3">
        <span class="text-sm font-semibold text-zinc-700">Totaal</span>
        <span class="text-lg font-bold text-emerald-700">{@total_label} uur</span>
      </div>
    </div>
    """
  end

  defp student?(user) do
    roles = Map.get(user, "roles", [])
    Enum.any?(roles, &(&1 in ["student", "studenten"]))
  end

  # Rond af op halve uren (zelfde afronding als AttendanceReport.format_hours)
  defp format_total(value) when is_number(value) do
    value
    |> float_to_half_hour()
    |> :erlang.float_to_binary(decimals: 1)
    |> String.replace(".", ",")
  end

  defp format_total(_), do: "0,0"

  defp float_to_half_hour(value) when is_number(value) do
    # Rond af naar dichtstbijzijnde halve uur (0.0, 0.5, 1.0, ...)
    Float.round(value * 2.0, 0) / 2.0
  end
end
