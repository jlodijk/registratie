defmodule RegistratieWeb.AttendanceController do
  use RegistratieWeb, :controller

  alias Registratie.AttendanceReport
  alias Registratie.AttendancePdf
  alias Registratie.OaseRules

  plug RegistratieWeb.Plugs.RequireAuthenticatedUser
  plug RegistratieWeb.Plugs.AuthorizeRole, "begeleider"

  def index(conn, params) do
    students = AttendanceReport.list_students()
    selected = Map.get(params, "student", "")
    rules = OaseRules.fetch_rules()

    {report, conn} =
      case String.trim(selected) do
        "" -> {nil, conn}
        student_name ->
          case AttendanceReport.generate(student_name) do
            {:ok, data} -> {data, conn}
            {:error, message} -> {nil, put_flash(conn, :error, message)}
          end
      end

    render(conn, :index,
      page_title: "Aanwezigheid",
      students: students,
      selected_student: String.trim(selected),
      report: report,
      rules: rules
    )
  end

  def export(conn, %{"student" => student}) do
    trimmed = String.trim(student || "")

    with true <- trimmed != "",
         {:ok, report} <- AttendanceReport.generate(trimmed),
         {:ok, pdf_binary} <- AttendancePdf.render(report),
         {:ok, filename} <- save_pdf(trimmed, pdf_binary) do
      conn
      |> put_flash(:info, "PDF opgeslagen als #{filename}.")
      |> redirect(to: ~p"/attendance?student=#{trimmed}")
    else
      false ->
        conn
        |> put_flash(:error, "Selecteer eerst een student.")
        |> redirect(to: ~p"/attendance")

      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/attendance?student=#{trimmed}")
    end
  end

  defp save_pdf(student, binary) do
    today = Date.utc_today() |> Date.to_iso8601()
    sanitized_name = student |> String.replace(~r/[^A-Za-z0-9_-]/, "-")
    filename = "#{sanitized_name}-#{today}.pdf"
    base_dir =
      System.get_env("REG_PRINT_HOME") ||
        System.get_env("HOME") ||
        System.get_env("USERPROFILE") ||
        File.cwd!()

    dir = Path.join(base_dir, "printen")

    with :ok <- File.mkdir_p(dir),
         :ok <- File.write(Path.join(dir, filename), binary) do
      {:ok, filename}
    else
      {:error, reason} -> {:error, "Kon PDF niet opslaan: #{reason}"}
    end
  end
end
