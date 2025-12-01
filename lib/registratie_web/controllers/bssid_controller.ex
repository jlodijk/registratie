defmodule RegistratieWeb.BssidController do
  use RegistratieWeb, :controller

  import Phoenix.Component, only: [to_form: 2]

  alias Registratie.Couch

  plug RegistratieWeb.Plugs.RequireAuthenticatedUser
  plug RegistratieWeb.Plugs.AuthorizeRole, "admin"

  @bbsid_db "bbsid"

  def index(conn, _params) do
    entries = fetch_entries()

    render(conn, :index,
      page_title: "BSSID beheer",
      form: to_form(%{}, as: :bbsid),
      entries: entries
    )
  end

  def create(conn, %{"bbsid" => params}) do
    case build_doc(params) do
      {:ok, doc} ->
        case Couch.create_doc(@bbsid_db, doc) do
          %{"ok" => true} ->
            conn
            |> put_flash(:info, "BSSID #{doc["BBSID"]} is toegevoegd.")
            |> redirect(to: ~p"/bbsids")

          %{"error" => "conflict"} ->
            conn
            |> put_flash(:error, "BSSID bestaat al.")
            |> redirect(to: ~p"/bbsids")

          %{"error" => error, "reason" => reason} ->
            conn
            |> put_flash(:error, "#{error}: #{reason}")
            |> redirect(to: ~p"/bbsids")
        end

      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/bbsids")
    end
  rescue
    exception ->
      conn
      |> put_flash(:error, Exception.message(exception))
      |> redirect(to: ~p"/bbsids")
  end

  def edit(conn, %{"id" => id}) do
    case fetch_entry(id) do
      {:ok, entry} ->
        locations = entry["Locatie"] || []

        render(conn, :edit,
          page_title: "BSSID wijzigen",
          entry: entry,
          locations: if(locations == [], do: [""], else: locations),
          form:
            to_form(
              %{
                "bssid" => entry["BBSID"],
                "locations" => locations
              },
              as: :bbsid
            )
        )

      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/bbsids")
    end
  end

  def update(conn, %{"id" => id, "bbsid" => params}) do
    with {:ok, _entry} <- fetch_entry(id),
         {:ok, locations} <- build_locations(params) do
      case Couch.update_doc(@bbsid_db, id, %{"Locatie" => locations}) do
        %{"ok" => true} ->
          conn
          |> put_flash(:info, "BSSID is bijgewerkt.")
          |> redirect(to: ~p"/bbsids")

        %{"error" => error, "reason" => reason} ->
          conn
          |> put_flash(:error, "#{error}: #{reason}")
          |> redirect(to: ~p"/bbsids/#{id}/edit")
      end
    else
      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/bbsids/#{id}/edit")
    end
  rescue
    exception ->
      conn
      |> put_flash(:error, Exception.message(exception))
      |> redirect(to: ~p"/bbsids/#{id}/edit")
  end

  def delete(conn, %{"id" => id}) do
    case Couch.delete_doc(@bbsid_db, id) do
      %{"ok" => true} ->
        conn
        |> put_flash(:info, "BSSID is verwijderd.")
        |> redirect(to: ~p"/bbsids")

      %{"error" => error, "reason" => reason} ->
        conn
        |> put_flash(:error, "#{error}: #{reason}")
        |> redirect(to: ~p"/bbsids")
    end
  rescue
    exception ->
      conn
      |> put_flash(:error, Exception.message(exception))
      |> redirect(to: ~p"/bbsids")
  end

  defp fetch_entries do
    case Couch.list_docs(@bbsid_db) do
      %{"rows" => rows} ->
        rows
        |> Enum.map(&Map.get(&1, "doc"))
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(&(Map.get(&1, "type") == "bbsid"))

      _ ->
        []
    end
  rescue
    _ -> []
  end

  defp fetch_entry(id) do
    {:ok, Couch.get_doc(@bbsid_db, id)}
  rescue
    _ -> {:error, "BSSID niet gevonden."}
  end

  defp build_doc(params) do
    raw_bssid =
      params
      |> Map.get("bssid", "")
      |> to_string()
      |> String.trim()

    with {:ok, locations} <- build_locations(params) do
      normalized_id = "bbsid:" <> sanitize_bssid(raw_bssid)

      cond do
        raw_bssid == "" ->
          {:error, "BSSID is verplicht."}

        true ->
          doc = %{
            "_id" => normalized_id,
            "BBSID" => String.upcase(raw_bssid),
            "Locatie" => locations,
            "type" => "bbsid"
          }

          {:ok, doc}
      end
    end
  end

  defp build_locations(params) do
    locations =
      params
      |> Map.get("locations", [])
      |> normalize_locations()

    if locations == [] do
      {:error, "Voeg minimaal één locatie toe."}
    else
      {:ok, locations}
    end
  end

  defp sanitize_bssid(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^0-9a-f]/, "")
  end

  defp normalize_locations(value) when is_list(value) do
    value
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_locations(value) do
    value
    |> to_string()
    |> String.split(~r/[\n,]+/, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end
