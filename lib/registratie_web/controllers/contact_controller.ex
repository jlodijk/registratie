defmodule RegistratieWeb.ContactController do
  use RegistratieWeb, :controller

  alias Registratie.Couch

  plug RegistratieWeb.Plugs.RequireAuthenticatedUser when action in [:edit, :update]
  plug RegistratieWeb.Plugs.AuthorizeRole, "admin" when action in [:edit, :update]

  def index(conn, _params) do
    case fetch_contact() do
      {:ok, contact} ->
        contact = enrich_contact(contact)

        render(conn, :index,
          page_title: "Contact",
          contact: contact,
          editable: admin?(conn.assigns[:current_user])
        )

      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/home")
    end
  end

  def edit(conn, _params) do
    case fetch_contact() do
      {:ok, contact} ->
        contact = enrich_contact(contact)
        render(conn, :edit, page_title: "Contact bewerken", contact: contact)

      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/contact")
    end
  end

  def update(conn, %{"contact" => params}) do
    case persist_contact(params) do
      :ok ->
        conn
        |> put_flash(:info, "Contactgegevens bijgewerkt.")
        |> redirect(to: ~p"/contact")

      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/contact/bewerken")
    end
  end

  def update(conn, _params) do
    conn
    |> put_flash(:error, "Ongeldige invoer.")
    |> redirect(to: ~p"/contact/bewerken")
  end

  defp fetch_contact do
    {:ok, Couch.get_doc("contact", "StichtingAsha")}
  rescue
    exception -> {:error, "Kon contactgegevens niet laden: #{Exception.message(exception)}"}
  end

  defp persist_contact(params) do
    updates = normalize_contact(params)

    case Couch.update_doc("contact", "StichtingAsha", updates) do
      %{"ok" => true} -> :ok
      %{"error" => error, "reason" => reason} -> {:error, "#{error}: #{reason}"}
      other -> {:error, "Onbekend antwoord: #{inspect(other)}"}
    end
  rescue
    exception -> {:error, Exception.message(exception)}
  end

  defp normalize_contact(params) do
    contactpersoon = Map.get(params, "contactpersoon", %{})

    %{
      "adres" => trim_field(params["adres"]),
      "postcode" => trim_field(params["postcode"]),
      "woonplaats" => trim_field(params["woonplaats"]),
      "email" => trim_field(params["email"]),
      "doel" => trim_field(params["doel"]),
      "contactpersoon" => %{
        "naam" => trim_field(contactpersoon["naam"]),
        "functie" => trim_field(contactpersoon["functie"]),
        "tel" => trim_field(contactpersoon["tel"]),
        "email" => trim_field(contactpersoon["email"]),
        "foto" => trim_field(contactpersoon["foto"])
      }
    }
  end

  defp enrich_contact(contact) do
    person = Map.get(contact, "contactpersoon", %{})
    photo_url = build_photo_url(Map.get(person, "foto"))

    contact
    |> Map.put("contactpersoon", Map.put(person, "photo_url", photo_url))
  end

  defp trim_field(value) when is_binary(value), do: String.trim(value)
  defp trim_field(_), do: ""

  defp build_photo_url(nil), do: nil
  defp build_photo_url(""), do: nil

  defp build_photo_url(path) do
    trimmed = String.trim(path)

    cond do
      trimmed == "" -> nil
      String.starts_with?(trimmed, "http") -> trimmed
      true -> "/images/#{Path.basename(trimmed)}"
    end
  end

  defp admin?(%{} = user) do
    roles =
      user
      |> Map.get("roles", [])
      |> List.wrap()

    "admin" in roles
  end

  defp admin?(_), do: false
end
