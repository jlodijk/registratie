defmodule RegistratieWeb.StudentOverviewController do
  use RegistratieWeb, :controller

  alias Registratie.Couch

  @db "studenten"
  @contacts_db "contact_persoon_school"

  plug RegistratieWeb.Plugs.RequireAuthenticatedUser
  plug RegistratieWeb.Plugs.AuthorizeRole, "begeleider"

  def index(conn, params) do
    students = list_students()
    selected = params["id"]
    student = if selected in [nil, ""], do: nil, else: fetch_student(selected)
    contact_people = contacts_for_student(student)

    render(conn, :index,
      page_title: "Studentoverzicht",
      students: students,
      selected_student_id: selected || "",
      student: student,
      contact_people: contact_people
    )
  end

  defp list_students do
    case Couch.list_docs(@db) do
      %{"rows" => rows} ->
        rows
        |> Enum.map(&Map.get(&1, "doc"))
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(&(Map.get(&1, "type") == "student"))
        |> Enum.sort_by(&String.downcase(Map.get(&1, "name", "")))

      _ ->
        []
    end
  rescue
    _ -> []
  end

  defp fetch_student(id) do
    Couch.get_doc(@db, id)
  rescue
    _ -> nil
  end

  defp contacts_for_student(nil), do: []

  defp contacts_for_student(student) do
    opleiding =
      student
      |> Map.get("opleiding")
      |> normalize_opleiding()

    if opleiding == "" do
      []
    else
      list_contacts()
      |> Enum.filter(fn contact ->
        contact
        |> Map.get("opleiding", [])
        |> Enum.map(&normalize_opleiding/1)
        |> Enum.any?(&(&1 == opleiding))
      end)
    end
  end

  defp list_contacts do
    case Couch.list_docs(@contacts_db) do
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

  defp normalize_opleiding(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.downcase()
  end
end
