defmodule RegistratieWeb.ContactPersonSchoolController do
  use RegistratieWeb, :controller

  import Phoenix.Component, only: [to_form: 2]

  alias Registratie.Couch

  @db "contact_persoon_school"

  plug RegistratieWeb.Plugs.RequireAuthenticatedUser
  plug :ensure_manager

  def index(conn, params) do
    contacts = list_contacts()
    mode = params["mode"] || "new"
    selected_id = params["id"]
    selected_contact = Enum.find(contacts, &(&1["_id"] == selected_id))

    render(conn, :index,
      page_title: "Contactpersonen scholen",
      contacts: contacts,
      mode: mode,
      selected_id: selected_id,
      selected_contact: selected_contact,
      new_form: to_form(%{}, as: :contact),
      edit_form:
        selected_contact
        |> contact_to_form_data()
        |> to_form(as: :contact)
    )
  end

  def create(conn, %{"contact" => params}) do
    doc = build_doc(params)

    case Couch.create_doc(@db, doc) do
      %{"ok" => true} ->
        conn
        |> put_flash(:info, "Contactpersoon toegevoegd.")
        |> redirect(to: ~p"/contactpersonen")

      %{"error" => error, "reason" => reason} ->
        conn
        |> put_flash(:error, "Opslaan mislukt: #{error} #{reason}")
        |> redirect(to: ~p"/contactpersonen")
    end
  rescue
    exception ->
      conn
      |> put_flash(:error, "Opslaan mislukt: #{Exception.message(exception)}")
      |> redirect(to: ~p"/contactpersonen")
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Ongeldig formulier.")
    |> redirect(to: ~p"/contactpersonen")
  end

  def update(conn, %{"id" => id, "contact" => params}) do
    updates = build_update(params)

    case Couch.update_doc(@db, id, updates) do
      %{"ok" => true} ->
        conn
        |> put_flash(:info, "Contactpersoon bijgewerkt.")
        |> redirect(to: ~p"/contactpersonen?mode=edit")

      %{"error" => error, "reason" => reason} ->
        conn
        |> put_flash(:error, "#{error}: #{reason}")
        |> redirect(to: ~p"/contactpersonen?mode=edit&id=#{id}")
    end
  rescue
    exception ->
      conn
      |> put_flash(:error, Exception.message(exception))
      |> redirect(to: ~p"/contactpersonen?mode=edit&id=#{id}")
  end

  def delete(conn, %{"id" => id}) do
    case Couch.delete_doc(@db, id) do
      %{"ok" => true} ->
        conn
        |> put_flash(:info, "Contactpersoon verwijderd.")
        |> redirect(to: ~p"/contactpersonen?mode=delete")

      %{"error" => error, "reason" => reason} ->
        conn
        |> put_flash(:error, "#{error}: #{reason}")
        |> redirect(to: ~p"/contactpersonen?mode=delete")
    end
  rescue
    exception ->
      conn
      |> put_flash(:error, Exception.message(exception))
      |> redirect(to: ~p"/contactpersonen?mode=delete")
  end

  defp list_contacts do
    case Couch.list_docs(@db) do
      %{"rows" => rows} ->
        rows
        |> Enum.map(&Map.get(&1, "doc"))
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(&(Map.get(&1, "type") == "contact_persoon_school"))
        |> Enum.reject(&(String.trim(to_string(Map.get(&1, "name", ""))) == ""))
        |> Enum.sort_by(&String.downcase(Map.get(&1, "name", "")))

      _ ->
        []
    end
  rescue
    _ -> []
  end

  defp build_doc(params) do
    normalized = normalize_fields(params)

    %{
      "_id" =>
        "contact-" <>
          slugify(normalized["name"] <> "-" <> Integer.to_string(:erlang.unique_integer([:positive]))),
      "type" => "contact_persoon_school"
    }
    |> Map.merge(normalized)
  end

  defp slugify(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  defp contact_to_form_data(nil), do: %{}

  defp contact_to_form_data(contact) do
    %{
      "name" => contact["name"],
      "opleiding" => Enum.join(contact["opleiding"] || [], ", "),
      "tel" => contact["tel"],
      "email" => contact["email"]
    }
  end

  defp build_update(params) do
    normalize_fields(params)
  end

  defp normalize_fields(params) do
    name = params["name"] |> to_string() |> String.trim()

    opleiding =
      params["opleiding"]
      |> List.wrap()
      |> Enum.flat_map(&String.split(&1, [",", "\n"], trim: true))
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    %{
      "name" => name,
      "opleiding" => opleiding,
      "tel" => String.trim(to_string(params["tel"] || "")),
      "email" => String.trim(to_string(params["email"] || ""))
    }
  end

  defp ensure_manager(conn, _opts) do
    roles =
      conn.assigns[:current_user]
      |> Map.get("roles", [])
      |> List.wrap()

    if Enum.any?(roles, &(&1 in ["begeleider", "admin"])) do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:error, "Je hebt geen toegang tot deze pagina.")
      |> Phoenix.Controller.redirect(to: ~p"/home")
      |> Plug.Conn.halt()
    end
  end
end
