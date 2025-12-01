defmodule RegistratieWeb.NetworkController do
  use RegistratieWeb, :controller

  plug RegistratieWeb.Plugs.RequireAuthenticatedUser
  plug :ensure_bol2_student

  def index(conn, _params) do
    render(conn, :index,
      page_title: "Netwerk",
      instructions: instructions()
    )
  end

  defp ensure_bol2_student(conn, _opts) do
    user = conn.assigns[:current_user] || %{}

    if bol2_student?(user) do
      conn
    else
      conn
      |> put_flash(:error, "Deze pagina is alleen beschikbaar voor BOL 2 studenten.")
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

  defp instructions do
    [
      "Loop langs iedere ruimte in de school en voer een meting uit.",
      "Noteer de SSID/BSSID, signaalsterkte en andere Wi-Fi gegevens.",
      "Gebruik een speedtest (bijv. speedtest.net) om download/upload/ping te meten.",
      "Vul daarna het netwerk inventarisatieformulier in per ruimte."
    ]
  end
end
