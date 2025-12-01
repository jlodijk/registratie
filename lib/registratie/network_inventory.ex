defmodule Registratie.NetworkInventory do
  @moduledoc """
  Opslag voor netwerkinventarisaties per ruimte in CouchDB (`netwerk` database).
  """

  alias Registratie.Couch

  @db Application.compile_env(:registratie, :network_db, "netwerk")

  @fields [
    :room,
    :date,
    :student_name,
    :ssid,
    :bssid,
    :signal_dbm,
    :frequency_band,
    :channel,
    :security_type,
    :link_speed,
    :speedtest_download,
    :speedtest_upload,
    :ping,
    :ipv4,
    :gateway
  ]

  def submit(params, user) do
    normalized = normalize(params)

    with :ok <- validate_required(normalized),
         hostname <- doc_id(normalized),
         entry <- build_entry(normalized, user),
         {:ok, existing} <- fetch(hostname, rescue?: true),
         {:ok, doc} <- persist(existing, hostname, entry) do
      {:ok, doc}
    else
      {:error, _} = error -> error
    end
  end

  def fetch(id, opts \\ []) do
    try do
      {:ok, Couch.get_doc(@db, id)}
    rescue
      _ ->
        if Keyword.get(opts, :rescue?, false), do: {:ok, nil}, else: {:error, :not_found}
    end
  end

  defp persist(nil, id, entry) do
    doc =
      %{
        "_id" => id,
        "type" => "network_inventory",
        "entries" => [entry]
      }
      |> put_timestamps()

    save_doc(doc, id)
  end

  defp persist(%{"entries" => entries} = doc, id, entry) do
    updated_doc =
      doc
      |> Map.put("entries", entries ++ [entry])
      |> put_timestamps()

    save_doc(updated_doc, id)
  end

  defp save_doc(doc, id) do
    case Couch.put_doc(@db, id, doc) do
      %{"ok" => true, "rev" => rev} -> {:ok, Map.put(doc, "_rev", rev)}
      %{"ok" => true} -> {:ok, doc}
      %{"error" => error, "reason" => reason} -> {:error, "#{error}: #{reason}"}
      other -> {:error, "Onbekend antwoord van CouchDB: #{inspect(other)}"}
    end
  rescue
    exception -> {:error, Exception.message(exception)}
  end

  defp normalize(params) do
    Enum.reduce(@fields, %{}, fn field, acc ->
      value =
        Map.get(params, field) ||
          Map.get(params, Atom.to_string(field))

      Map.put(acc, field, normalize_value(value))
    end)
  end

  defp normalize_value(nil), do: ""
  defp normalize_value(value) when is_binary(value), do: String.trim(value)
  defp normalize_value(value), do: value |> to_string() |> String.trim()

  defp validate_required(data) do
    missing =
      Enum.filter(@fields, fn field ->
        Map.get(data, field) in [nil, ""]
      end)

    case missing do
      [] -> :ok
      [first | _] -> {:error, "#{first} is verplicht."}
    end
  end

  defp doc_id(data) do
    room = Map.get(data, :room, "onbekend") |> String.replace(~r/\s+/, "-")
    date = Map.get(data, :date, Date.utc_today() |> Date.to_iso8601())
    "NET-#{room}-#{date}"
  end

  defp build_entry(data, user) do
    %{
      "data" => Map.new(data, fn {k, v} -> {Atom.to_string(k), v} end),
      "submitted_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "submitted_on" => Date.utc_today() |> Date.to_iso8601(),
      "submitted_by" => Map.get(user, "name") || Map.get(user, :name) || "onbekend",
      "submitted_by_full_name" => Map.get(user, "name") || Map.get(user, :name) || "onbekend"
    }
  end

  defp put_timestamps(doc) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    doc
    |> Map.put("updated_at", now)
    |> Map.put_new("created_at", now)
  end
end
