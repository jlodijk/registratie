defmodule RegistratieWeb.StudentController do
  use RegistratieWeb, :controller

  import Phoenix.Component, only: [to_form: 2]

  alias Registratie.{Couch, DateUtils, Student}

  plug RegistratieWeb.Plugs.RequireAuthenticatedUser when action in [:new, :create]
  plug RegistratieWeb.Plugs.AuthorizeRole, "begeleider" when action in [:new, :create]

  @students_db "studenten"
  @users_db "_users"
  @weekdays [
    %{label: "Maandag", value: "ma"},
    %{label: "Dinsdag", value: "di"},
    %{label: "Woensdag", value: "wo"},
    %{label: "Donderdag", value: "do"},
    %{label: "Vrijdag", value: "vr"}
  ]

  @field_mappings %{
    "name" => :name,
    "voornaam" => :voornaam,
    "achternaam" => :achternaam,
    "email" => :email,
    "opleiding" => :opleiding,
    "mobiel" => :mobiel,
    "woonplaats" => :woonplaats,
    "postcode" => :postcode,
    "hostname" => :hostname,
    "startDatum" => :startDatum,
    "eindDatum" => :eindDatum
  }

  def new(conn, _params) do
    defaults = default_form_data()

    render(conn, :new,
      page_title: "Student aanmaken",
      form: to_form(defaults, as: :student),
      weekdays: @weekdays,
      selected_days: default_stage_days()
    )
  end

  def create(conn, %{"student" => params}) do
    role = current_role(conn)

    with {:ok, attrs} <- build_student_attrs(params),
         {:ok, doc} <- Student.new(attrs, role) do
      log_student(attrs, doc)

      with {:ok, _resp} <- persist_student(doc),
           :ok <- create_student_user(doc) do
        conn
        |> put_flash(:info, "Student #{doc.name} is aangemaakt.")
        |> redirect(to: ~p"/home")
      else
        {:error, message} ->
          re_render_with_error(conn, params, message)
      end
    else
      {:error, message} ->
        re_render_with_error(conn, params, message)
    end
  end

  defp re_render_with_error(conn, params, message) do
    conn
    |> put_flash(:error, "Student niet aangemaakt: #{message}")
    |> render(:new,
      page_title: "Student aanmaken",
      form: to_form(form_data(params), as: :student),
      weekdays: @weekdays,
      selected_days: normalize_stage_days(Map.get(params, "stageDagen"))
    )
  end

  defp build_student_attrs(params) do
    stage_days = normalize_stage_days(Map.get(params, "stageDagen"))

    if stage_days == [] do
      {:error, "Kies minimaal één stagedag."}
    else
      attrs =
        params
        |> Enum.reduce(%{}, fn {key, value}, acc ->
          case Map.fetch(@field_mappings, key) do
            {:ok, field} ->
              Map.put(acc, field, normalize_value(field, value))

            :error ->
              acc
          end
        end)
        |> Map.put(:stageDagen, stage_days)
        |> set_status_from_end_date()

      with {:ok, attrs_with_postcode} <- ensure_valid_postcode(attrs) do
        {:ok, attrs_with_postcode}
      end
    end
  end

  defp normalize_value(field, value) when field in [:startDatum, :eindDatum] do
    DateUtils.iso_from_input(value)
  end

  defp normalize_value(_field, value) when is_binary(value) do
    String.trim(value)
  end

  defp normalize_value(_field, nil), do: ""
  defp normalize_value(_field, value), do: value

  defp ensure_valid_postcode(%{postcode: postcode} = attrs) do
    formatted =
      postcode
      |> to_string()
      |> String.trim()
      |> String.upcase()
      |> String.replace(~r/\s+/, "")

    cond do
      formatted == "" ->
        {:error, "Postcode is verplicht."}

      Regex.match?(~r/^\d{4}[A-Z]{2}$/, formatted) ->
        <<numbers::binary-size(4), letters::binary-size(2)>> = formatted
        {:ok, Map.put(attrs, :postcode, numbers <> " " <> letters)}

      true ->
        {:error, "Voer een geldige Nederlandse postcode in (bijv. 1234 AB)."}
    end
  end

  defp ensure_valid_postcode(attrs), do: {:ok, attrs}

  defp set_status_from_end_date(attrs) do
    end_date = Map.get(attrs, :eindDatum, "")

    status =
      case DateUtils.iso_from_input(end_date) do
        "" ->
          "Onbekend"

        iso_date ->
          today = DateUtils.today()

          case Date.from_iso8601(iso_date) do
            {:ok, date} ->
              if Date.diff(date, today) > 0 do
                "Actief"
              else
                "Verlopen"
              end

            _ ->
              "Onbekend"
          end
      end

    Map.put(attrs, :status, status)
  end

  defp normalize_stage_days(value) do
    allowed = Enum.map(@weekdays, & &1.value)

    value
    |> List.wrap()
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 in allowed))
    |> Enum.uniq()
  end

  defp persist_student(doc) do
    case Couch.create_doc(@students_db, doc) do
      %{"ok" => true} = resp ->
        {:ok, resp}

      %{"error" => error, "reason" => reason} ->
        {:error, "#{error}: #{reason}"}

      other ->
        {:error, "Onbekend antwoord van CouchDB: #{inspect(other)}"}
    end
  rescue
    exception ->
      {:error, Exception.message(exception)}
  end

  defp current_role(conn) do
    conn.assigns[:current_user]
    |> extract_role()
  end

  defp extract_role(%{} = user) do
    roles =
      cond do
        Map.has_key?(user, "roles") -> Map.get(user, "roles", [])
        Map.has_key?(user, :roles) -> Map.get(user, :roles, [])
        true -> []
      end

    cond do
      Enum.any?(roles, &(&1 in ["begeleider", "admin"])) -> "begeleider"
      Enum.any?(roles, &(&1 in ["student", "studenten"])) -> "student"
      true -> nil
    end
  end

  defp extract_role(_), do: nil

  defp default_form_data, do: %{}
  defp form_data(params), do: params

  defp default_stage_days do
    Enum.map(@weekdays, & &1.value)
  end

  defp log_student(attrs, doc) do
    IO.inspect(attrs, label: "Student attrs na validatie")
    IO.inspect(doc, label: "Student doc (naar CouchDB)")
    :ok
  end

  defp create_student_user(%{name: name}) when is_binary(name) do
    password = build_student_password(name)

    user_doc = %{
      "_id" => "org.couchdb.user:#{name}",
      "name" => name,
      "type" => "user",
      "roles" => ["studenten"],
      "password" => password,
      "firstPassword" => true
    }

    case Couch.create_doc(@users_db, user_doc) do
      %{"ok" => true} ->
        :ok

      %{"error" => "conflict"} ->
        {:error, "CouchDB-gebruiker #{name} bestaat al."}

      %{"error" => error, "reason" => reason} ->
        {:error, "#{error}: #{reason}"}

      other ->
        {:error, "Onbekend antwoord van CouchDB: #{inspect(other)}"}
    end
  rescue
    exception ->
      {:error, Exception.message(exception)}
  end

  defp create_student_user(_), do: {:error, "Ongeldige studentnaam."}

  defp build_student_password(name) when is_binary(name) do
    trimmed = String.trim(name)

    if String.length(trimmed) == 4 do
      trimmed <> "1234"
    else
      trimmed <> "123"
    end
  end

  defp build_student_password(_), do: "student123"
end
