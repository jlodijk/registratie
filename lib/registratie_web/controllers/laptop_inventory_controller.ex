defmodule RegistratieWeb.LaptopInventoryController do
  use RegistratieWeb, :controller

  import Phoenix.Component, only: [to_form: 2]

  alias Registratie.LaptopInventory

  plug RegistratieWeb.Plugs.RequireAuthenticatedUser
  plug :ensure_bol2_student

  def new(conn, params) do
    hostname = params["hostname"] |> to_string() |> String.trim()
    existing = fetch_existing(hostname)
    student_name = default_student_name(conn.assigns.current_user)
    date_iso = Date.utc_today() |> Date.to_iso8601()

    form_defaults =
      %{
        student_name: student_name,
        date: date_iso,
        hostname: hostname
      }

    render(conn, :new,
      form: to_form(form_defaults, as: :laptop),
      existing: existing,
      page_title: "Laptop inventarisatie",
      instructions: instructions(),
      auto_student_name: student_name,
      auto_date_iso: date_iso
    )
  end

  def create(conn, %{"laptop" => params}) do
    student_name = default_student_name(conn.assigns.current_user)
    date_iso = Date.utc_today() |> Date.to_iso8601()

    enriched_params =
      params
        |> Map.put("student_name", student_name)
        |> Map.put("date", date_iso)

    case LaptopInventory.submit(enriched_params, conn.assigns.current_user) do
      {:ok, _doc} ->
        hostname = Map.get(enriched_params, "hostname") |> to_string() |> String.trim()

        conn
        |> put_flash(:info, "Inventarisatie opgeslagen onder hostname #{hostname}.")
        |> redirect(to: ~p"/laptop-inventarisatie?hostname=#{hostname}")

      {:error, message} ->
        form = to_form(enriched_params, as: :laptop)

        conn
        |> put_flash(:error, message)
        |> render(:new,
          form: form,
          existing: fetch_existing(Map.get(enriched_params, "hostname")),
          page_title: "Laptop inventarisatie",
          instructions: instructions(),
          auto_student_name: student_name,
          auto_date_iso: date_iso
        )
    end
  end

  defp fetch_existing(""), do: nil

  defp fetch_existing(nil), do: nil

  defp fetch_existing(hostname) do
    hostname = hostname |> to_string() |> String.trim()

    case LaptopInventory.fetch(hostname) do
      {:ok, doc} -> doc
      _ -> nil
    end
  end

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

  defp default_student_name(user) do
    Map.get(user, "name") || Map.get(user, :name) || ""
  end

  defp bol2_student?(user) do
    user
    |> Map.get("opleiding") 
    |> to_string()
    |> String.downcase()
    |> String.contains?("bol 2")
  end

  defp instructions do
    [
      "Zoek eerst de hostname van de laptop (bij Windows: Instellingen > Info > Apparaatnaam). Dit wordt de sleutel in CouchDB.",
      "Controleer of er al een inventarisatie bestaat voor deze hostname. Staat er al één, dan moet een andere BOL 2 student de tweede inventarisatie doen.",
      "Vul alle hardware-gegevens in zoals je ze in Windows, BIOS of hulpprogramma's kunt terugvinden.",
      "Sla het formulier op; de gegevens worden veilig in de database 'laptops' opgeslagen."
    ]
  end
end
