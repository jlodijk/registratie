defmodule RegistratieWeb.StudentOverviewController do
  use RegistratieWeb, :controller

  alias Registratie.Couch
  alias Registratie.Attendance

  @db "studenten"
  @contacts_db "contact_persoon_school"
  @users_db "_users"
  @attendance_db Application.compile_env(:registratie, :attendance_db, "aanwezig")

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
      # Pass the full flash map to components; ensures Phoenix.Flash.get/2 receives a map.
      flash: get_flash(conn),
      contact_people: contact_people
    )
  end

  def add_extra_hours(conn, %{
        "student" => student,
        "hours" => hours,
        "date" => date,
        "reason" => reason
      }) do
    trimmed_student = String.trim(student || "")
    trimmed_reason = String.trim(reason || "")

    with true <- trimmed_student != "",
         {:ok, parsed_hours} <- parse_hours(hours),
         {:ok, parsed_date} <- parse_date(date),
         :ok <-
           Attendance.add_extra_hours(
             trimmed_student,
             parsed_date,
             parsed_hours,
             trimmed_reason,
             current_user_name(conn)
           ) do
      conn
      |> put_flash(:info, "Extra uren toegevoegd voor #{trimmed_student}.")
      |> redirect(to: ~p"/studenten/overzicht?id=#{trimmed_student}")
    else
      false ->
        conn
        |> put_flash(:error, "Kies een student.")
        |> redirect(to: ~p"/studenten/overzicht")

      {:error, message} ->
        conn
        |> put_flash(:error, "Kon extra uren niet opslaan: #{message}")
        |> redirect(to: "/studenten/overzicht?id=#{trimmed_student}#extra-uren")
    end
  end

  def add_extra_hours(conn, _params) do
    conn
    |> put_flash(:error, "Ongeldig verzoek.")
    |> redirect(to: ~p"/studenten/overzicht")
  end

  def delete(conn, %{"student" => student_param}) do
    student = String.trim(student_param || "")

    with true <- student != "",
         {:ok, _} <- maybe_delete_attendance(student),
         {:ok, _} <- maybe_delete_student_doc(student),
         {:ok, _} <- maybe_delete_user_doc(student) do
      conn
      |> put_flash(:info, "Student #{student} en aanwezigheid verwijderd.")
      |> redirect(to: ~p"/studenten/overzicht")
    else
      false ->
        conn
        |> put_flash(:error, "Kies een student om te verwijderen.")
        |> redirect(to: ~p"/studenten/overzicht")

      {:error, message} ->
        conn
        |> put_flash(:error, "Verwijderen mislukt: #{message}")
        |> redirect(to: ~p"/studenten/overzicht")
    end
  end

  defp list_students do
    roles = roles_map()

    case Couch.list_docs(@db) do
      %{"rows" => rows} ->
        rows
        |> Enum.map(&Map.get(&1, "doc"))
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(&(Map.get(&1, "type") == "student"))
        |> Enum.filter(&pure_student?(Map.get(&1, "name"), roles))
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

  defp roles_map do
    case Couch.list_docs(@users_db) do
      %{"rows" => rows} ->
        rows
        |> Enum.map(&Map.get(&1, "doc"))
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(&(Map.get(&1, "type") == "user"))
        |> Enum.reduce(%{}, fn doc, acc ->
          Map.put(acc, Map.get(doc, "name"), Map.get(doc, "roles", []))
        end)

      _ ->
        %{}
    end
  rescue
    _ -> %{}
  end

  defp pure_student?(name, roles_map) do
    roles = Map.get(roles_map, name, [])
    roles != [] and Enum.all?(roles, &(&1 in ["student", "studenten"]))
  end

  defp parse_hours(val) when is_binary(val) do
    val
    |> String.replace(",", ".")
    |> Float.parse()
    |> case do
      {num, _} when num >= 0 -> {:ok, num}
      _ -> {:error, "Voer een geldig aantal uren in."}
    end
  end

  defp parse_hours(val) when is_number(val) and val >= 0, do: {:ok, val}
  defp parse_hours(_), do: {:error, "Voer een geldig aantal uren in."}

  defp parse_date(value) when is_binary(value) do
    value = String.trim(value)

    with iso when iso != "" <- Registratie.DateUtils.iso_from_input(value),
         {:ok, date} <- Date.from_iso8601(iso) do
      {:ok, date}
    else
      _ ->
        {:error, "Ongeldige datum. Gebruik dd-mm-jjjj."}
    end
  end

  defp parse_date(_), do: {:error, "Ongeldige datum."}

  defp current_user_name(conn) do
    get_in(conn.assigns, [:current_user, "name"]) ||
      get_in(conn.assigns, [:current_user, :name]) ||
      "onbekend"
  end

  defp normalize_opleiding(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.downcase()
  end

  defp maybe_delete_student_doc(student) do
    case Couch.delete_doc(@db, student) do
      %{"ok" => true} -> {:ok, :deleted}
      %{"error" => "not_found"} -> {:ok, :missing}
      %{"error" => err, "reason" => reason} -> {:error, "#{err}: #{reason}"}
      other -> {:error, "Onbekend antwoord van CouchDB: #{inspect(other)}"}
    end
  rescue
    exception -> {:error, Exception.message(exception)}
  end

  defp maybe_delete_attendance(student) do
    start_key = "aanwezig-#{student}-"
    end_key = start_key <> "\ufff0"

    case Couch.list_docs_range(@attendance_db, start_key, end_key) do
      %{"rows" => rows} ->
        rows
        |> Enum.map(&Map.get(&1, "doc"))
        |> Enum.reject(&is_nil/1)
        |> Enum.each(fn doc ->
          case Map.get(doc, "_id") do
            nil -> :skip
            id -> Couch.delete_doc(@attendance_db, id)
          end
        end)

        {:ok, :deleted}

      other ->
        {:error, "Kon aanwezigheidsrecords niet ophalen: #{inspect(other)}"}
    end
  rescue
    exception -> {:error, Exception.message(exception)}
  end

  defp maybe_delete_user_doc(student) do
    id = "org.couchdb.user:#{student}"

    case Couch.delete_doc(@users_db, id) do
      %{"ok" => true} -> {:ok, :deleted}
      %{"error" => "not_found"} -> {:ok, :missing}
      %{"error" => err, "reason" => reason} -> {:error, "#{err}: #{reason}"}
      other -> {:error, "Onbekend antwoord van CouchDB: #{inspect(other)}"}
    end
  rescue
    exception -> {:error, Exception.message(exception)}
  end
end
