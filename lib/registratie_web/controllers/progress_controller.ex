defmodule RegistratieWeb.ProgressController do
  use RegistratieWeb, :controller

  alias Registratie.Progress
  alias Registratie.AttendanceReport

  plug RegistratieWeb.Plugs.RequireAuthenticatedUser
  plug RegistratieWeb.Plugs.AuthorizeRole, "begeleider"

  def index(conn, params) do
    selected_student = String.trim(Map.get(params, "student", ""))
    selected_date = String.trim(Map.get(params, "date", ""))

    filters = %{
      student_name: blank_to_nil(selected_student),
      date: blank_to_nil(selected_date)
    }

    entries = Progress.entries(filters)
    students = AttendanceReport.list_students()

    render(conn, :index,
      page_title: "Voortgang",
      entries: entries,
      students: students,
      selected_student: selected_student,
      selected_date: selected_date
    )
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
