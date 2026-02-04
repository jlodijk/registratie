defmodule RegistratieWeb.StudentProfileController do
  use RegistratieWeb, :controller

  import Phoenix.Component, only: [to_form: 2]

  alias Registratie.{Couch, DateUtils}

  plug RegistratieWeb.Plugs.RequireAuthenticatedUser
  plug :ensure_student_role

  @students_db "studenten"
  @allowed_fields ~w(voornaam achternaam email mobiel woonplaats postcode)

  def edit(conn, _params) do
    with {:ok, student} <- fetch_student(conn) do
      render(conn, :edit,
        page_title: "Mijn gegevens",
        student_name: student["name"],
        student_data: student,
        stage_days: student["stageDagen"] || [],
        form: to_form(form_data(student), as: :student)
      )
    else
      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/home")
    end
  end

  def update(conn, %{"student" => params}) do
    with {:ok, student} <- fetch_student(conn),
         {:ok, updated} <- apply_updates(student, params),
         {:ok, _resp} <- save_student(updated) do
      conn
      |> put_flash(:info, "Je gegevens zijn bijgewerkt.")
      |> redirect(to: ~p"/home")
    else
      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/profiel")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(
      :error,
      "Zelf uitschrijven is gedeactiveerd. Neem contact op met een begeleider of administrator."
    )
    |> redirect(to: ~p"/profiel")
  end

  defp fetch_student(conn) do
    case conn.assigns[:current_user] do
      %{"name" => name} -> load_student(name)
      _ -> {:error, "Geen student gevonden voor dit account."}
    end
  end

  defp load_student(name) do
    {:ok, Couch.get_doc(@students_db, name)}
  rescue
    _ -> {:error, "Kon studentgegevens niet ophalen."}
  end

  defp form_data(student) do
    student
    |> Map.take(@allowed_fields)
    |> Enum.into(%{}, fn {k, v} -> {String.to_atom(k), v} end)
  end

  defp apply_updates(student, params) do
    updates =
      Enum.reduce(@allowed_fields, %{}, fn field, acc ->
        value =
          params
          |> Map.get(field, "")
          |> to_string()
          |> String.trim()

        Map.put(acc, field, value)
      end)

    now = DateUtils.today_iso()

    updated_student =
      student
      |> Map.merge(updates)
      |> Map.put("updated_at", now)

    {:ok, updated_student}
  end

  defp save_student(student) do
    case Couch.put_doc(@students_db, student["_id"], student) do
      %{"ok" => true} = resp -> {:ok, resp}
      %{"error" => error, "reason" => reason} -> {:error, "#{error}: #{reason}"}
      other -> {:error, "Onbekend antwoord: #{inspect(other)}"}
    end
  rescue
    exception -> {:error, Exception.message(exception)}
  end

  defp ensure_student_role(conn, _opts) do
    user = conn.assigns[:current_user] || %{}
    roles = Map.get(user, "roles") || Map.get(user, :roles) || []

    if "studenten" in roles do
      conn
    else
      conn
      |> put_flash(:error, "Alleen studenten kunnen dit scherm bekijken.")
      |> redirect(to: ~p"/home")
      |> halt()
    end
  end

end
