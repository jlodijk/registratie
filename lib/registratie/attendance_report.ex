defmodule Registratie.AttendanceReport do
  @moduledoc """
  Bouwt aanwezigheidsrapportages per student.
  """

  alias Registratie.Couch

  @attendance_db Application.compile_env(:registratie, :attendance_db, "aanwezig")
  @students_db "studenten"
  @bbsid_db "bbsid"
  @time_zone "Europe/Amsterdam"
  @weekday_codes %{1 => "ma", 2 => "di", 3 => "wo", 4 => "do", 5 => "vr", 6 => "za", 7 => "zo"}
  @weekday_names %{1 => "maandag", 2 => "dinsdag", 3 => "woensdag", 4 => "donderdag", 5 => "vrijdag", 6 => "zaterdag", 7 => "zondag"}
  @month_names ~w(jan feb mar apr mei jun jul aug sep okt nov dec)

  def list_students do
    case Couch.list_docs(@students_db) do
      %{"rows" => rows} ->
        rows
        |> Enum.map(&Map.get(&1, "doc"))
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(&(Map.get(&1, "type") == "student"))
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
         {:ok, allowed_bssid} <- allowed_bssids() do
      rows =
        events
        |> normalize_events()
        |> Enum.filter(&(&1.type in ["login", "logout"]))
        |> Enum.group_by(&DateTime.to_date(&1.timestamp))
        |> Enum.map(&build_row(&1, student, allowed_bssid))
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

  defp allowed_bssids do
    case Couch.list_docs(@bbsid_db) do
      %{"rows" => rows} ->
        set =
          rows
          |> Enum.map(&Map.get(&1, "doc"))
          |> Enum.reject(&is_nil/1)
          |> Enum.filter(&(Map.get(&1, "type") == "bbsid"))
          |> Enum.map(&Map.get(&1, "BBSID"))
          |> Enum.reject(&(&1 in [nil, ""]))
          |> Enum.map(&String.upcase/1)
          |> MapSet.new()

        {:ok, set}

      _ ->
        {:ok, MapSet.new()}
    end
  rescue
    _ -> {:ok, MapSet.new()}
  end

  defp normalize_events(docs) do
    docs
    |> Enum.reduce([], fn doc, acc ->
      case DateTime.from_iso8601(Map.get(doc, "tijd", "")) do
        {:ok, dt, _} ->
          [%{type: Map.get(doc, "event"), timestamp: shift_zone(dt), hostname: Map.get(doc, "hostname"), bssid: Map.get(doc, "bssid")} | acc]

        _ ->
          acc
      end
    end)
  end

  defp build_row({date, events}, student, allowed_bssid) do
    stage_days = MapSet.new(stage_days(student))
    day_code = Map.get(@weekday_codes, Date.day_of_week(date))

    if day_code && MapSet.member?(stage_days, day_code) do
      {first_login, last_logout} = pick_events(events)
      issues = issues_for(first_login, last_logout, student, allowed_bssid)

      hours =
        if issues == [] do
          compute_hours(first_login, last_logout)
        else
          0.0
        end

      message = Enum.join(issues, " / ")

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

  defp issues_for(nil, nil, _student, _allowed), do: ["Geen login", "Geen logout"]
  defp issues_for(nil, _logout, _student, _allowed), do: ["Geen login"]
  defp issues_for(_login, nil, _student, _allowed), do: ["Geen logout"]

  defp issues_for(login, logout, student, allowed_bssid) do
    expected_host = student |> fetch_field("hostname") |> normalize_text()
    login_host_value = sanitize_text(login.hostname)
    logout_host_value = sanitize_text(logout.hostname)
    login_host = normalize_text(login_host_value)
    logout_host = normalize_text(logout_host_value)

    host_issue =
      cond do
        expected_host == "" -> nil
        login_host == expected_host and logout_host == expected_host -> nil
        true -> "Onbekende hostname (#{display_value(login_host_value)}/#{display_value(logout_host_value)})"
      end

    login_bssid = normalize_bssid(login.bssid)
    logout_bssid = normalize_bssid(logout.bssid)

    bssid_issue =
      cond do
        MapSet.size(allowed_bssid) == 0 -> nil
        MapSet.member?(allowed_bssid, login_bssid) and MapSet.member?(allowed_bssid, logout_bssid) -> nil
        true -> "Onbekende BSSID (#{display_value(login_bssid)}/#{display_value(logout_bssid)})"
      end

    Enum.reject([host_issue, bssid_issue], &is_nil/1)
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
        base = max(minutes / 60 - 0.5, 0)
        Float.floor(base * 2) / 2
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
    Float.floor(value * 2) / 2
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

  defp normalize_bssid(nil), do: nil
  defp normalize_bssid(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.upcase()
  end

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
