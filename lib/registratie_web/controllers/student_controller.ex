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
    password = normalize_password(Map.get(params, "password"))
    email = normalize_email(Map.get(params, "email"))
    username = normalize_value(:name, Map.get(params, "name"))

    with :ok <- ensure_password(password),
         :ok <- ensure_username_format(username),
         :ok <- ensure_username_available(username),
         :ok <- ensure_email_present(email),
         :ok <- ensure_email_available(email),
         {:ok, attrs} <- build_student_attrs(params),
         {:ok, attrs} <- put_email(attrs, email),
         {:ok, doc} <- Student.new(attrs, role) do
      log_student(attrs, doc)

      with {:ok, _resp} <- persist_student(doc),
           :ok <- create_student_user(doc, password) do
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

  defp ensure_password(nil), do: {:error, "Wachtwoord is verplicht."}
  defp ensure_password(password) when byte_size(password) < 6,
    do: {:error, "Wachtwoord moet minimaal 6 tekens zijn."}
  defp ensure_password(_), do: :ok

  # Extra check zodat we meteen een duidelijke foutmelding geven (username 4-5 tekens)
  defp ensure_username_format(nil), do: {:error, "Gebruikersnaam is verplicht."}

  defp ensure_username_format(username) do
    len = String.length(username)

    cond do
      len < 4 -> {:error, "Gebruikersnaam moet minimaal 4 tekens bevatten."}
      len > 5 -> {:error, "Gebruikersnaam mag maximaal 5 tekens bevatten."}
      true -> :ok
    end
  end

  defp ensure_username_available(nil), do: {:error, "Gebruikersnaam is verplicht."}
  defp ensure_username_available(username) do
    id = "org.couchdb.user:#{username}"

    case Couch.get_doc(@users_db, id) do
      %{"error" => _} -> :ok
      %{} -> {:error, "Gebruikersnaam bestaat al."}
    end
  rescue
    # 404/not found -> ok
    _ -> :ok
  end

  defp ensure_email_present(nil), do: {:error, "E-mailadres is verplicht."}
  defp ensure_email_present(_), do: :ok

  defp ensure_email_available(nil), do: {:error, "E-mailadres is verplicht."}
  defp ensure_email_available(email) do
    case Couch.find_docs(@students_db, %{"email" => %{"$eq" => email}}, limit: 1) do
      %{"docs" => []} -> :ok
      %{"docs" => [_ | _]} -> {:error, "E-mailadres is al in gebruik."}
      _ -> :ok
    end
  rescue
    _ -> :ok
  end

  defp put_email(_attrs, nil), do: {:error, "E-mailadres is verplicht."}
  defp put_email(attrs, email), do: {:ok, Map.put(attrs, :email, email)}

  defp normalize_password(nil), do: nil
  defp normalize_password(str) when is_binary(str) do
    case String.trim(str) do
      "" -> nil
      trimmed -> trimmed
    end
  end
  defp normalize_password(_), do: nil

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

  defp normalize_email(nil), do: nil
  defp normalize_email(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
    |> case do
      "" -> nil
      val -> val
    end
  end
  defp normalize_email(_), do: nil

  defp ensure_valid_postcode(%{postcode: postcode} = attrs) do
    formatted =
      postcode
      |> to_string()
      |> String.trim()
      |> String.upcase()
      |> String.replace(~r/\s+/, "")

    cond do
      formatted == "" ->
        {:ok, Map.put(attrs, :postcode, "")}

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

  defp create_student_user(%{name: name}, password) when is_binary(name) do
    password = password || build_student_password(name)

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
        maybe_create_user_secondary(user_doc)

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

  defp create_student_user(_, _), do: {:error, "Ongeldige studentnaam."}

  defp maybe_create_user_secondary(user_doc) do
    case secondary_config() do
      :disabled ->
        :ok

      %{url: url, username: username, password: password} = _cfg ->
        base = String.trim_trailing(url, "/") <> "/_users"
        auth = {:basic, "#{username}:#{password}"}

        case Req.post(Req.new(base_url: base, auth: auth, json: true), json: user_doc) do
          {:ok, %{status: status}} when status in 200..299 -> :ok
          {:ok, %{status: 409}} -> :ok
          {:ok, %{status: status, body: body}} ->
            {:error, "Secundaire CouchDB gaf status #{status}: #{inspect(body)}"}

          {:error, exception} ->
            {:error, "Secundaire CouchDB fout: #{Exception.message(exception)}"}
        end
    end
  end

  defp secondary_config do
    case Application.get_env(:registratie, :couchdb_secondary_url) do
      nil -> :disabled
      "" -> :disabled
      url ->
        username = Application.get_env(:registratie, :couchdb_secondary_username)
        password = Application.get_env(:registratie, :couchdb_secondary_password)

        if username && password do
          %{url: url, username: username, password: password}
        else
          :disabled
        end
    end
  end

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
