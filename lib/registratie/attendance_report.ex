defmodule Registratie.AttendanceReport do
  @moduledoc """
  Bouwt aanwezigheidsrapportages per student.
  """

  alias Registratie.Couch

  @attendance_db Application.compile_env(:registratie, :attendance_db, "aanwezig")
  @students_db "studenten"
  @bbsid_db "bbsid"
  @users_db "_users"
  @time_zone "Europe/Amsterdam"
  @weekday_codes %{1 => "ma", 2 => "di", 3 => "wo", 4 => "do", 5 => "vr", 6 => "za", 7 => "zo"}
  @weekday_names %{1 => "maandag", 2 => "dinsdag", 3 => "woensdag", 4 => "donderdag", 5 => "vrijdag", 6 => "zaterdag", 7 => "zondag"}
  @month_names ~w(jan feb mar apr mei jun jul aug sep okt nov dec)

  def list_students do
    roles = roles_map()

    case Couch.list_docs(@students_db) do
      %{"rows" => rows} ->
        rows
        |> Enum.map(&Map.get(&1, "doc"))
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(&(Map.get(&1, "type") == "student"))
        |> Enum.filter(&(pure_student?(Map.get(&1, "name") || Map.get(&1, "_id"), roles)))
        |> Enum.map(&format_student_entry/1)
        |> Enum.sort_by(&String.downcase(&1.label))

      _ ->
        []
    end
  rescue
    _ -> []
  end

  def generate(student_name) when is_binary(student_name) do
    with {:ok, student} <- fetch_student(student_name),
         {:ok, events} <- fetch_events(student_name),
         {:ok, allowed_wifi} <- allowed_wifi_ssids() do
      rows =
        events
        |> normalize_events()
        |> Enum.group_by(&event_date/1)
        |> Enum.map(&build_row(&1, student, allowed_wifi))
        |> Enum.reject(&is_nil/1)
        |> Enum.sort_by(& &1.date, {:desc, Date})

      total_hours = rows |> Enum.map(& &1.hours) |> Enum.sum()

      {:ok,
       %{
         student: student,
         rows: rows,
         total_hours: total_hours,
         total_label: format_hours(total_hours),
         stats: build_stats(rows)
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def generate(_), do: {:error, "Onbekende student"}

  defp fetch_student(name) do
    {:ok, Couch.get_doc(@students_db, name)}
  rescue
    _ -> {:error, "Student niet gevonden."}
  end

  defp fetch_events(name) do
    start_key = "aanwezig-#{name}-"
    end_key = start_key <> "\ufff0"

    case Couch.list_docs_range(@attendance_db, start_key, end_key) do
      %{"rows" => rows} ->
        docs =
          rows
          |> Enum.map(&Map.get(&1, "doc"))
          |> Enum.reject(&is_nil/1)

        {:ok, docs}

      other ->
        {:error, "Kon aanwezigheidsdata niet ophalen: #{inspect(other)}"}
    end
  rescue
    exception -> {:error, Exception.message(exception)}
  end

  # To avoid false negatives when access points change BSSID, we now pin to SSID.
  # Only log an issue when the SSID differs from the approved networks below.
  defp allowed_wifi_ssids do
    MapSet.new([
      "GU INTERNET",
      "FREE WIFI UTRECHT",
      "DOPENHANS"
    ])
    |> then(&{:ok, &1})
  end

  defp normalize_events(docs) do
    docs
    |> Enum.reduce([], fn doc, acc ->
      case Map.get(doc, "event") do
        "extra_hours" ->
          date = Map.get(doc, "datum")

          with {:ok, parsed_date} <- Date.from_iso8601(to_string(date)) do
            [%{type: "extra_hours", date: parsed_date, hours: Map.get(doc, "hours") |> to_number(), reason: Map.get(doc, "reason") |> to_string()} | acc]
          else
            _ -> acc
          end

        _ ->
          case DateTime.from_iso8601(Map.get(doc, "tijd", "")) do
            {:ok, dt, _} ->
              [
                %{
                  type: Map.get(doc, "event"),
                  timestamp: shift_zone(dt),
                  hostname: Map.get(doc, "hostname"),
                  ssid: Map.get(doc, "ssid"),
                  bssid: Map.get(doc, "bssid")
                }
                | acc
              ]

            _ ->
              acc
          end
      end
    end)
  end

  defp build_row({date, events}, student, allowed_wifi) do
    stage_days = MapSet.new(stage_days(student))
    day_code = Map.get(@weekday_codes, Date.day_of_week(date))
    extras = Enum.filter(events, &(&1.type == "extra_hours"))

    # Toon altijd als er extra uren zijn; anders alleen op stagedagen
    if (day_code && MapSet.member?(stage_days, day_code)) || extras != [] do
      {first_login, last_logout} = pick_events(Enum.filter(events, &(&1.type in ["login", "logout"])))
      issues =
        issues_for(first_login, last_logout, student, allowed_wifi)
        |> Enum.reject(&(&1 in ["Geen login", "Geen logout"]))

      hours =
        compute_hours(first_login, last_logout)
        |> Kernel.+(sum_extra_hours(extras))

      extra_message =
        extras
        |> Enum.map(fn e -> "Extra uren #{display_value(e.hours)} (#{String.trim(e.reason) |> display_value()})" end)

      message =
        (issues ++ extra_message)
        |> Enum.reject(&(&1 in [nil, ""]))
        |> Enum.join(" / ")

      login_local = first_login && local_time(first_login.timestamp)
      logout_local = last_logout && local_time(last_logout.timestamp)

      %{
        date: date,
        date_label: format_date(date),
        weekday: weekday_label(date),
        first_login: format_time(first_login),
        last_logout: format_time(last_logout),
        hours: hours,
        hours_label: format_hours(hours),
        message: message,
        late?: late_login?(login_local),
        early?: early_logout?(logout_local)
      }
    else
      nil
    end
  end

  defp stage_days(student) do
    student
    |> fetch_field("stageDagen")
    |> List.wrap()
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.downcase/1)
  end

  defp pick_events(events) do
    sorted = Enum.sort_by(events, & &1.timestamp)
    logins = sorted |> Enum.filter(&(&1.type == "login"))
    logouts = sorted |> Enum.filter(&(&1.type == "logout"))
    {List.first(logins), last_logout_or_login(logouts, logins)}
  end

  defp last_logout_or_login([], logins), do: List.last(logins)
  defp last_logout_or_login(logouts, _logins), do: List.last(logouts)

  defp issues_for(login, logout, student, allowed_wifi) do
    expected_host = student |> fetch_field("hostname") |> normalize_text()
    login_host = login.hostname |> sanitize_text() |> normalize_text()
    logout_host = logout.hostname |> sanitize_text() |> normalize_text()

    host_issue =
      cond do
        expected_host == "" -> nil
        login_host == expected_host and (logout_host == expected_host or logout_host == "") -> nil
        true -> "Onbekende laptop"
      end

    login_ssid = normalize_ssid(login.ssid)
    logout_ssid = normalize_ssid(logout.ssid)

    wifi_issue =
      cond do
        MapSet.size(allowed_wifi) == 0 -> nil
        is_nil(login_ssid) and is_nil(logout_ssid) -> nil
        MapSet.member?(allowed_wifi, login_ssid) and
            (is_nil(logout_ssid) or MapSet.member?(allowed_wifi, logout_ssid)) ->
          nil
        MapSet.member?(allowed_wifi, logout_ssid) and is_nil(login_ssid) ->
          nil

        login_ssid == logout_ssid and not is_nil(login_ssid) ->
          "Onbekende WiFi (#{display_value(login_ssid)})"

        true ->
          "Onbekende WiFi (#{display_value(login_ssid)}/#{display_value(logout_ssid)})"
      end

    Enum.reject([host_issue, wifi_issue], &is_nil/1)
  end

  defp compute_hours(nil, _), do: 0.0
  defp compute_hours(_, nil), do: 0.0

  defp compute_hours(login, logout) do
    adjusted_logout =
      case DateTime.compare(logout.timestamp, login.timestamp) do
        :lt -> %{logout | timestamp: login.timestamp}
        _ -> logout
      end

    login_time = local_time(login.timestamp)
    logout_time = local_time(adjusted_logout.timestamp)

    cond do
      before_hour?(login_time, 10) and not before_hour?(logout_time, 16) ->
        8.0

      true ->
        minutes = DateTime.diff(adjusted_logout.timestamp, login.timestamp, :minute)
        work_minutes =
          cond do
            # Als de eerste inlog na 13:00 is, geen verplichte pauze aftrekken
            local_time(login.timestamp).hour >= 13 ->
              max(minutes, 0)

            true ->
              # Trek 30 minuten pauze af, maar niet onder nul
              max(minutes - 30, 0)
          end

        work_minutes / 60.0
    end
  end

  defp before_hour?(dt, hour) do
    dt.hour < hour
  end

  defp late_login?(nil), do: false
  defp late_login?(dt), do: not before_hour?(dt, 10)

  defp early_logout?(nil), do: false
  defp early_logout?(dt), do: before_hour?(dt, 16)

  defp format_time(nil), do: "-"
  defp format_time(%{timestamp: ts}), do: Calendar.strftime(ts, "%H:%M")

  defp format_hours(value) do
    formatted =
      value
      |> float_to_half_hour()
      |> :erlang.float_to_binary(decimals: 1)
      |> String.replace(".", ",")

    formatted
  end

  defp float_to_half_hour(value) when is_number(value) do
    # Rond af naar dichtstbijzijnde halve uur (0.0, 0.5, 1.0, ...)
    Float.round(value * 2.0, 0) / 2.0
  end

  defp format_date(%Date{} = date) do
    month = Enum.at(@month_names, date.month - 1)
    "#{pad(date.day)} #{month} #{date.year}"
  end

  defp weekday_label(%Date{} = date) do
    Map.get(@weekday_names, Date.day_of_week(date), "")
  end

  defp pad(value) do
    value
    |> Integer.to_string()
    |> String.pad_leading(2, "0")
  end

  defp format_student_entry(doc) do
    name = Map.get(doc, "name") || Map.get(doc, "_id")
    base_label =
      [Map.get(doc, "voornaam"), Map.get(doc, "achternaam")]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.join(" ")
      |> String.trim()

    label =
      cond do
        name in [nil, ""] -> base_label
        base_label == "" -> name
        true -> String.trim("#{base_label} (#{name})")
      end

    %{name: name, label: label}
  end

  defp fetch_field(map, key) when is_binary(key) do
    Map.get(map, key) || Map.get(map, safe_to_atom(key))
  end

  defp fetch_field(map, key) when is_atom(key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp fetch_field(_, _), do: nil

  defp sanitize_text(nil), do: ""
  defp sanitize_text(value), do: value |> to_string() |> String.trim()

  defp normalize_text(nil), do: ""
  defp normalize_text(value), do: value |> sanitize_text() |> String.downcase()

  defp display_value(""), do: "-"
  defp display_value(nil), do: "-"
  defp display_value(value), do: value

  defp safe_to_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
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

  defp normalize_ssid(nil), do: nil

  defp normalize_ssid(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.upcase()
  end

  defp event_date(%{type: "extra_hours", date: %Date{} = date}), do: date
  defp event_date(%{timestamp: ts}), do: DateTime.to_date(ts)

  defp sum_extra_hours(extras) do
    extras
    |> Enum.map(&to_number(Map.get(&1, :hours)))
    |> Enum.reject(&is_nil/1)
    |> Enum.sum()
  end

  defp to_number(val) when is_number(val), do: val
  defp to_number(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      _ -> nil
    end
  end
  defp to_number(_), do: nil

  defp shift_zone(%DateTime{} = dt) do
    case DateTime.shift_zone(dt, @time_zone) do
      {:ok, local} -> local
      _ -> dt
    end
  end

  defp local_time(%DateTime{} = dt) do
    shift_zone(dt)
  end

  defp build_stats(rows) do
    %{
      late: Enum.count(rows, &(&1[:late?] == true)),
      early: Enum.count(rows, &(&1[:early?] == true)),
      issues: Enum.count(rows, &((row_message(&1)) not in [nil, ""]))
    }
  end

  defp row_message(row), do: Map.get(row, :message) || Map.get(row, "message")
end
