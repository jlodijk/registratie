defmodule Registratie.Attendance do
  @moduledoc """
  Schrijft aanwezigheidsevents weg in CouchDB.
  """
  require Logger

  alias Registratie.Couch

  @db Application.compile_env(:registratie, :attendance_db, "aanwezig")

  @type user_session :: %{optional(String.t()) => any()}

  @doc """
  Log een succesvolle login.
  """
  @spec log_login(user_session(), map()) :: :ok | :error
  def log_login(user_session, metadata \\ %{}) do
    log_event("login", user_session, metadata)
  end

  @doc """
  Log een logout.
  """
  @spec log_logout(user_session(), map()) :: :ok | :error
  def log_logout(user_session, metadata \\ %{}) do
    log_event("logout", user_session, metadata)
  end

  @time_zone "Europe/Amsterdam"

  defp log_event(event, %{"name" => name}, metadata) when is_binary(name) do
    datetime = current_datetime()
    iso_timestamp = DateTime.to_iso8601(datetime)
    local_date = datetime |> DateTime.to_date() |> Date.to_iso8601()
    local_time = Calendar.strftime(datetime, "%H:%M:%S")

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
        "bssid" => pick(metadata, :bssid),
        "platform" => pick(metadata, :platform)
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    case Couch.create_doc(@db, doc) do
      %{"ok" => true} -> :ok
      other -> log_error("Unexpected response", other)
    end
  rescue
    exception ->
      log_error("Exception tijdens log_event", exception)
  end

  defp log_event(_event, _user_session, _metadata), do: :error

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
    Logger.warning("#{message}: #{inspect(detail)}")
    :error
  end

  defp current_datetime do
    case DateTime.now(@time_zone) do
      {:ok, dt} -> DateTime.truncate(dt, :second)
      {:error, _} -> DateTime.utc_now() |> DateTime.truncate(:second)
    end
  end
end
