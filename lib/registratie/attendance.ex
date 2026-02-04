defmodule Registratie.Attendance do
  @moduledoc """
  Schrijft aanwezigheidsevents weg in CouchDB.
  """
  require Logger

  alias Registratie.Couch
  alias Registratie.DateUtils

  @db Application.compile_env(:registratie, :attendance_db, "aanwezig")
  @bbsid_db "bbsid"

  @type user_session :: %{optional(String.t()) => any()}

  @doc """
  Log een succesvolle login.
  """
  @spec log_login(user_session(), map()) :: :ok | {:error, atom()}
  def log_login(user_session, metadata \\ %{}) do
    maybe_log_event(:login, user_session, metadata)
  end

  @doc """
  Log een logout.
  """
  @spec log_logout(user_session(), map()) :: :ok | {:error, atom()}
  def log_logout(user_session, metadata \\ %{}) do
    maybe_log_event(:logout, user_session, metadata)
  end

  @doc """
  Voeg handmatig extra uren toe voor een student (bijv. correctie of extra shift).
  """
  @spec add_extra_hours(String.t(), Date.t(), number(), String.t(), String.t()) ::
          :ok | {:error, String.t()}
  def add_extra_hours(student_name, %Date{} = date, hours, reason, created_by)
      when is_binary(student_name) and is_number(hours) do
    Logger.debug("add_extra_hours #{student_name} #{date} hours=#{hours}")

    with :ok <- ensure_in_stage_period(student_name, date) do
      do_add_extra_hours(student_name, date, hours, reason, created_by)
    end
  end

  def add_extra_hours(_student_name, _date, _hours, _reason, _created_by),
    do: {:error, "Ongeldige invoer."}

  defp do_add_extra_hours(student_name, %Date{} = date, hours, reason, created_by) do
    doc = %{
      "_id" => build_id(student_name),
      "type" => "aanwezig",
      "event" => "extra_hours",
      "name" => student_name,
      "datum" => Date.to_iso8601(date),
      "hours" => hours,
      "reason" => reason,
      "created_by" => created_by
    }

    case Couch.create_doc(@db, doc) do
      %{"ok" => true} = resp ->
        Logger.info("extra_hours saved: #{inspect(resp)}")
        :ok

      %{"error" => err, "reason" => reason_msg} = resp ->
        Logger.warning("extra_hours failed: #{inspect(resp)}")
        {:error, "#{err}: #{reason_msg}"}

      other ->
        Logger.warning("extra_hours unexpected: #{inspect(other)}")
        {:error, "Onbekend antwoord: #{inspect(other)}"}
    end
  rescue
    exception ->
      Logger.warning("extra_hours exception: #{Exception.message(exception)}")
      {:error, Exception.message(exception)}
  end

  @time_zone "Europe/Amsterdam"

  defp maybe_log_event(_event, nil, _metadata), do: :error

  defp maybe_log_event(event, user_session, metadata) do
    cond do
      not pure_student?(user_session) ->
        :ok

      not hostname_matches?(user_session, metadata) ->
        Logger.info("Attendance skip: hostname mismatch for #{user_session["name"]}.")
        {:error, :hostname_mismatch}

      not network_allowed?(metadata) ->
        Logger.info("Attendance skip: netwerk onbekend voor #{user_session["name"]}.")
        {:error, :network_unknown}

      not stage_day_allowed?(user_session) ->
        Logger.info("Attendance skip: geen stagedag voor #{user_session["name"]}.")
        {:error, :no_stage_day}

      true ->
        log_event(event_label(event), user_session, metadata)
    end
  end

  defp pure_student?(%{"roles" => roles}) when is_list(roles) do
    roles != [] and Enum.all?(roles, &(&1 in ["student", "studenten"]))
  end

  defp pure_student?(_), do: false

  defp hostname_matches?(user_session, metadata) do
    stored_raw = Map.get(user_session, "hostname")
    incoming_raw = Map.get(metadata, :hostname)

    stored = normalize_hostname(stored_raw)
    incoming = normalize_hostname(incoming_raw)

    case {stored, incoming} do
      {"", _} ->
        log_hostname(:missing_stored, stored_raw, incoming_raw, stored, incoming)
        false

      {s, ""} when s != "" ->
        # Geen hostname meegekomen, val terug op de bekende host van de student
        log_hostname(:missing_incoming_fallback, stored_raw, incoming_raw, stored, incoming)
        true

      {s, i} when s == i ->
        true

      _ ->
        log_hostname(:mismatch, stored_raw, incoming_raw, stored, incoming)
        false
    end
  end

  defp network_allowed?(metadata) do
    network =
      metadata
      |> Map.get(:ssid)
      |> normalize_text()

    allowed = allowed_networks()

    cond do
      network == "" ->
        # Geen SSID binnengekregen; keur goed maar log
        log_network(:missing, network, allowed)
        true

      MapSet.size(allowed) == 0 ->
        # Geen whitelist beschikbaar; liever niet blokkeren
        log_network(:allowed_empty, network, allowed)
        true

      MapSet.member?(allowed, network) ->
        true

      true ->
        log_network(:unknown, network, allowed)
        false
    end
  end

  defp normalize_text(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_text(_), do: ""

  defp normalize_hostname(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/\s+/, "-")
    |> String.replace("_", "-")
    |> String.replace(~r/\.local$/, "")
    |> String.replace(~r/\.lan$/, "")
  end

  defp normalize_hostname(_), do: ""

  defp log_hostname(reason, stored_raw, incoming_raw, stored, incoming) do
    Logger.info(
      "attendance hostname #{reason}: stored=#{inspect(stored_raw)} (#{stored}) incoming=#{inspect(incoming_raw)} (#{incoming})"
    )
  end

  defp log_network(reason, incoming, allowed) do
    Logger.info(
      "attendance network #{reason}: incoming=#{inspect(incoming)} allowed=#{inspect(MapSet.to_list(allowed))}"
    )
  end

  defp allowed_networks do
    case Couch.list_docs(@bbsid_db) do
      %{"rows" => rows} ->
        rows
        |> Enum.map(&Map.get(&1, "doc"))
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(&(Map.get(&1, "type") == "bbsid"))
        |> Enum.flat_map(&extract_networks/1)
        |> Enum.map(&normalize_text/1)
        |> Enum.reject(&(&1 == ""))
        |> MapSet.new()

      _ ->
        MapSet.new()
    end
  rescue
    _ -> MapSet.new()
  end

  defp extract_networks(doc) do
    cond do
      is_list(Map.get(doc, "netwerk")) -> Map.get(doc, "netwerk")
      is_binary(Map.get(doc, "netwerk")) -> [Map.get(doc, "netwerk")]
      is_list(Map.get(doc, "network")) -> Map.get(doc, "network")
      is_binary(Map.get(doc, "network")) -> [Map.get(doc, "network")]
      is_binary(Map.get(doc, "ssid")) -> [Map.get(doc, "ssid")]
      is_binary(Map.get(doc, "SSID")) -> [Map.get(doc, "SSID")]
      true -> []
    end
  end

  defp event_label(:login), do: "login"
  defp event_label(:logout), do: "logout"
  defp event_label(other) when is_binary(other), do: other
  defp event_label(other), do: to_string(other)

  defp stage_day_allowed?(%{"name" => name}) when is_binary(name) do
    today = current_datetime() |> DateTime.to_date() |> weekday_code()

    with {:ok, student} <- fetch_student(name),
         days when is_list(days) <-
           student |> Map.get("stageDagen") |> List.wrap() |> normalize_days(),
         true <- days != [] do
      today in days
    else
      _ -> false
    end
  rescue
    _ -> false
  end

  defp stage_day_allowed?(_), do: false

  defp normalize_days(list) do
    Enum.map(list, fn day ->
      day
      |> to_string()
      |> String.trim()
      |> String.downcase()
    end)
    |> Enum.reject(&(&1 == ""))
  end

  defp weekday_code(%Date{} = date) do
    case Date.day_of_week(date) do
      1 -> "ma"
      2 -> "di"
      3 -> "wo"
      4 -> "do"
      5 -> "vr"
      6 -> "za"
      7 -> "zo"
      _ -> ""
    end
  end

  defp log_event(event, %{"name" => name}, metadata) when is_binary(name) do
    datetime = current_datetime()
    iso_timestamp = DateTime.to_iso8601(datetime)
    local_date = datetime |> DateTime.to_date() |> Date.to_iso8601()
    local_time = Calendar.strftime(datetime, "%H:%M:%S")

    stage_check = ensure_in_stage_period(name, datetime |> DateTime.to_date())

    doc =
      %{
        "_id" => build_id(name),
        "type" => "aanwezig",
        "name" => name,
        "tijd" => iso_timestamp,
        "datum" => local_date,
        "tijd_local" => local_time,
        "event" => event,
        "hostname" => pick(metadata, :hostname),
        "ssid" => pick(metadata, :ssid),
        "bssid" => pick(metadata, :bssid),
        "platform" => pick(metadata, :platform)
      }
      |> maybe_put_stage_check(stage_check)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    case Couch.create_doc(@db, doc) do
      %{"ok" => true} ->
        :ok

      other ->
        log_error("Unexpected response while writing attendance", other)
    end
  rescue
    exception ->
      log_error("Exception tijdens log_event", exception)
  end

  defp log_event(_event, _user_session, _metadata), do: :error

  defp maybe_put_stage_check(doc, :ok), do: doc

  defp maybe_put_stage_check(doc, {:error, reason}) do
    name = Map.get(doc, "name")

    Logger.warning(
      "Stage check failed for #{name}: #{inspect(reason)} — attendance wordt toch opgeslagen"
    )

    Map.put(doc, "stage_check", to_string(reason))
  end

  defp pick(metadata, key) do
    metadata
    |> Map.get(key)
    |> case do
      value when is_binary(value) and value != "" -> value
      _ -> nil
    end
  end

  defp build_id(name) do
    unique = System.system_time(:microsecond)
    "aanwezig-#{name}-#{unique}"
  end

  defp log_error(message, detail) do
    Logger.error("#{message}: #{inspect(detail)}")
    :error
  end

  defp current_datetime do
    case DateTime.now(@time_zone) do
      {:ok, dt} -> DateTime.truncate(dt, :second)
      {:error, _} -> DateTime.utc_now() |> DateTime.truncate(:second)
    end
  end

  @doc """
  Controleert of een datum binnen de stageperiode (startDatum/eindDatum) van een student valt.
  """
  defp ensure_in_stage_period(student, %Date{} = date) do
    with {:ok, doc} <- fetch_student(student),
         {:ok, start_date} <- parse_optional_date(Map.get(doc, "startDatum")),
         {:ok, end_date} <- parse_optional_date(Map.get(doc, "eindDatum")) do
      cond do
        start_date && Date.compare(date, start_date) == :lt ->
          Logger.info("stage check failed: before start #{start_date} for #{student}")
          {:error, "Datum valt voor startDatum (#{start_date})."}

        end_date && Date.compare(date, end_date) == :gt ->
          Logger.info("stage check failed: after end #{end_date} for #{student}")
          {:error, "Datum valt na eindDatum (#{end_date})."}

        true ->
          Logger.info("stage check ok for #{student} on #{date}")
          :ok
      end
    else
      {:error, reason} ->
        Logger.info("stage check error for #{student}: #{reason}")
        {:error, reason}
    end
  end

  defp fetch_student(name) do
    {:ok, Couch.get_doc("studenten", name)}
  rescue
    _ -> {:error, "Student niet gevonden."}
  end

  defp parse_optional_date(nil), do: {:ok, nil}
  defp parse_optional_date(""), do: {:ok, nil}

  defp parse_optional_date(value) when is_binary(value) do
    # Accepteer zowel ISO (yyyy-mm-dd) als Europese invoer (dd-mm-jjjj) die in oudere documenten kan staan.
    iso =
      value
      |> DateUtils.iso_from_input()

    cond do
      iso == "" ->
        {:error, "Ongeldige datum in studentrecord: #{value}"}

      true ->
        case Date.from_iso8601(iso) do
          {:ok, date} -> {:ok, date}
          _ -> {:error, "Ongeldige datum in studentrecord: #{value}"}
        end
    end
  end

  defp parse_optional_date(_), do: {:error, "Ongeldige datum in studentrecord."}
end
