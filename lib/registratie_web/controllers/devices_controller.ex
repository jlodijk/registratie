defmodule RegistratieWeb.DevicesController do
  use RegistratieWeb, :controller

  plug RegistratieWeb.Plugs.RequireAuthenticatedUser
  plug :ensure_bol2_student

  def index(conn, _params) do
    render(conn, :index,
      page_title: "Devices",
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
    opleiding =
      Map.get(user, "opleiding") ||
        Map.get(user, :opleiding) ||
        ""

    opleiding
    |> to_string()
    |> String.downcase()
    |> String.contains?("bol 2")
  end

  defp instructions do
    [
      "Bepaal eerst de hostname van de laptop (Instellingen > Info > Apparaatnaam). De inventarisatie wordt onder deze sleutel opgeslagen.",
      "Controleer of er al een inventarisatie bestaat voor deze hostname. Bestaat er al één? Laat een andere BOL 2 student de tweede controle doen.",
      "Verzamel de hardwaregegevens van het apparaat (CPU, RAM, opslag, etc.) en vul vervolgens het inventarisatieformulier in.",
      "Sla je bevindingen op via het formulier; de gegevens worden veilig bewaard in CouchDB (database: laptops)."
    ]
  end
end
