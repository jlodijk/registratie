defmodule RegistratieWeb.TaskController do
  use RegistratieWeb, :controller

  import Phoenix.Component, only: [to_form: 2]

  alias Registratie.{Couch, DateUtils, StandardTasks}

  @students_db "studenten"
  @tasks_db "taken"

  plug RegistratieWeb.Plugs.RequireAuthenticatedUser
  plug RegistratieWeb.Plugs.AuthorizeRole, "begeleider"

  def index(conn, _params) do
    students = list_students()
    tasks = list_tasks()

    render(conn, :index,
      page_title: "Taken",
      students: students,
      tasks: tasks,
      standard_tasks: standard_tasks(),
      form: to_form(default_form_data(), as: :task),
      statuses: statuses()
    )
  end

  def create(conn, %{"task" => params}) do
    case build_task_doc(params, conn.assigns[:current_user]) do
      {:ok, doc} ->
        case Couch.create_doc(@tasks_db, doc) do
          %{"ok" => true} ->
            conn
            |> put_flash(:info, "Taak toegevoegd.")
            |> redirect(to: ~p"/taken")

          %{"error" => error, "reason" => reason} ->
            conn
            |> put_flash(:error, "#{error}: #{reason}")
            |> redirect(to: ~p"/taken")
        end

      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/taken")
    end
  rescue
    exception ->
      conn
      |> put_flash(:error, "Kon taak niet opslaan: #{Exception.message(exception)}")
      |> redirect(to: ~p"/taken")
  end

  def update_status(conn, %{"id" => id, "status" => status}) do
    new_status = normalize_status(status)

    case Couch.update_doc(@tasks_db, id, %{"status" => new_status}) do
      %{"ok" => true} ->
        conn
        |> put_flash(:info, "Status bijgewerkt.")
        |> redirect(to: ~p"/taken")

      %{"error" => error, "reason" => reason} ->
        conn
        |> put_flash(:error, "#{error}: #{reason}")
        |> redirect(to: ~p"/taken")
    end
  rescue
    exception ->
      conn
      |> put_flash(:error, "Kon status niet bijwerken: #{Exception.message(exception)}")
      |> redirect(to: ~p"/taken")
  end

  defp list_students do
    case Couch.list_docs(@students_db) do
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

  defp list_tasks do
    case Couch.list_docs(@tasks_db) do
      %{"rows" => rows} ->
        rows
        |> Enum.map(&Map.get(&1, "doc"))
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(&(Map.get(&1, "type") == "taak"))
        |> Enum.sort_by(&Map.get(&1, "datum", ""), {:asc, String})

      _ ->
        []
    end
  rescue
    _ -> []
  end

  defp build_task_doc(params, current_user) do
    student_id = Map.get(params, "student") |> to_string() |> String.trim()
    taak = Map.get(params, "taak") |> to_string() |> String.trim()
    raw_date = Map.get(params, "datum")

    with {:student, %{} = student} <- {:student, fetch_student(student_id)},
         {:task, true} <- {:task, taak != ""} do
      doc = %{
        "_id" => unique_id(),
        "type" => "taak",
        "student_id" => student["_id"],
        "student_name" => display_name(student),
        "student_username" => student["name"],
        "taak" => taak,
        "datum" => normalize_date(raw_date),
        "status" => normalize_status(Map.get(params, "status")),
        "assigned_by" => Map.get(current_user || %{}, "name") || Map.get(current_user || %{}, :name)
      }

      {:ok, doc}
    else
      {:student, _} -> {:error, "Selecteer een geldige student."}
      {:task, _} -> {:error, "Taakomschrijving is verplicht."}
    end
  end

  defp fetch_student(""), do: nil
  defp fetch_student(id) do
    Couch.get_doc(@students_db, id)
  rescue
    _ -> nil
  end

  defp normalize_date(nil), do: DateUtils.today_iso()

  defp normalize_date(value) do
    value
    |> DateUtils.iso_from_input()
    |> case do
      "" -> DateUtils.today_iso()
      iso -> iso
    end
  end

  defp normalize_status(status) when status in ["open", "volbracht"], do: status
  defp normalize_status(status) when status in [nil, ""], do: "open"

  defp normalize_status(status) do
    status
    |> to_string()
    |> String.downcase()
    |> case do
      "volbracht" -> "volbracht"
      _ -> "open"
    end
  end

  defp display_name(student) do
    voornaam = Map.get(student, "voornaam") || ""
    achternaam = Map.get(student, "achternaam") || ""
    String.trim("#{voornaam} #{achternaam}")
  end

  defp unique_id do
    "taak-" <> Integer.to_string(:erlang.unique_integer([:positive]))
  end

  defp default_form_data do
    %{
      student: "",
      taak: "",
      datum: DateUtils.today_iso(),
      status: "open"
    }
  end

  defp statuses, do: ["open", "volbracht"]

  defp standard_tasks, do: StandardTasks.list()
end
