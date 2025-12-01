defmodule RegistratieWeb.NetworkInventoryController do
  use RegistratieWeb, :controller

  import Phoenix.Component, only: [to_form: 2]

  alias Registratie.NetworkInventory

  plug RegistratieWeb.Plugs.RequireAuthenticatedUser
  plug :ensure_bol2_student

  def new(conn, _params) do
    student_name = default_student_name(conn.assigns.current_user)
    date_iso = Date.utc_today() |> Date.to_iso8601()

    defaults = %{
      student_name: student_name,
      date: date_iso,
      room: ""
    }

    render_form(conn, defaults, nil)
  end

  def create(conn, %{"network" => params}) do
    student_name = default_student_name(conn.assigns.current_user)
    date_iso = Date.utc_today() |> Date.to_iso8601()

    enriched =
      params
      |> Map.put("student_name", student_name)
      |> Map.put("date", date_iso)

    case NetworkInventory.submit(enriched, conn.assigns.current_user) do
      {:ok, _doc} ->
        conn
        |> put_flash(:info, "Netwerkinventarisatie opgeslagen.")
        |> redirect(to: ~p"/network-inventarisatie")

      {:error, message} ->
        render_form(conn, enriched, message)
    end
  end

  defp render_form(conn, params, error_message) do
    form = to_form(params, as: :network)
    hostname = Map.get(params, "room", "") |> String.replace(~r/\s+/, "-")
    existing = fetch_existing(hostname)
    student_value = Map.get(params, "student_name") || Map.get(params, :student_name)
    date_value = Map.get(params, "date") || Map.get(params, :date)

    conn
    |> maybe_add_error(error_message)
    |> render(:new,
      page_title: "Netwerkinventarisatie",
      form: form,
      auto_student_name: student_value,
      auto_date_iso: date_value,
      existing: existing,
      instructions: instructions()
    )
  end

  defp fetch_existing(""), do: nil
  defp fetch_existing(nil), do: nil
  defp fetch_existing(room_id) do
    case NetworkInventory.fetch(room_id, rescue?: true) do
      {:ok, doc} -> doc
      _ -> nil
    end
  end

  defp maybe_add_error(conn, nil), do: conn
  defp maybe_add_error(conn, message), do: put_flash(conn, :error, message)

  defp ensure_bol2_student(conn, _opts) do
    user = conn.assigns[:current_user] || %{}

    if bol2_student?(user) do
      conn
    else
      conn
      |> put_flash(:error, "Deze inventarisatie is alleen beschikbaar voor BOL 2 studenten.")
      |> redirect(to: ~p"/home")
      |> halt()
    end
  end

  defp bol2_student?(user) do
    opleiding = Map.get(user, "opleiding") || Map.get(user, :opleiding) || ""

    opleiding
    |> to_string()
    |> String.downcase()
    |> String.contains?("bol 2")
  end

  defp default_student_name(user) do
    Map.get(user, "name") || Map.get(user, :name) || ""
  end

  defp instructions do
    [
      "Voer een Speedtest by Ookla (speedtest.net) uit en noteer download/upload/ping.",
      "Gebruik `netsh wlan show interfaces` om details zoals BSSID en signaalsterkte te vinden.",
      "Met een wifi-analyzer kun je kanaal en frequentieband controleren.",
      "Vul het formulier direct na elke ruimte in."
    ]
  end
end
