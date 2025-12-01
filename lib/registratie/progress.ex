defmodule Registratie.Progress do
  @moduledoc """
  Combine laptop- en netwerk-inventarisaties zodat begeleiders de voortgang kunnen zien.
  """

  alias Registratie.Couch

  @laptop_db Application.compile_env(:registratie, :laptops_db, "laptops")
  @network_db Application.compile_env(:registratie, :network_db, "netwerk")

  def entries(filters \\ %{}) do
    laptop_entries = collect_entries(@laptop_db, "Laptopinventarisatie")
    network_entries = collect_entries(@network_db, "Netwerkinventarisatie")

    (laptop_entries ++ network_entries)
    |> filter_by(filters)
    |> Enum.sort_by(&{&1.date, &1.student_name}, :desc)
  end

  defp collect_entries(db, label) do
    case Couch.list_docs(db) do
      %{"rows" => rows} ->
        rows
        |> Enum.map(&Map.get(&1, "doc"))
        |> Enum.reject(&is_nil/1)
        |> Enum.flat_map(&doc_entries(&1, label))

      _ ->
        []
    end
  rescue
    _ -> []
  end

  defp doc_entries(doc, label) do
    hostname = Map.get(doc, "hostname") || Map.get(doc, "_id")

    doc
    |> Map.get("entries", [])
    |> Enum.map(fn entry ->
      data = Map.get(entry, "data", %{})
      %{
        type: label,
        hostname: hostname,
        student_name: Map.get(entry, "submitted_by") || Map.get(data, "student_name") || "onbekend",
        date: Map.get(data, "date") || Map.get(entry, "submitted_on"),
        summary: summarize(label, data)
      }
    end)
  end

  defp summarize("Laptopinventarisatie", data) do
    [
      "CPU: #{Map.get(data, "cpu_name", "?")}",
      "RAM: #{Map.get(data, "ram_total", "?")} GB",
      "Opslag: #{Map.get(data, "storage_type", "?")}"
    ]
    |> Enum.join(" · ")
  end

  defp summarize("Netwerkinventarisatie", data) do
    [
      "SSID: #{Map.get(data, "ssid", "?")}",
      "Band: #{Map.get(data, "frequency_band", "?")}",
      "Ping: #{Map.get(data, "ping", "?")} ms"
    ]
    |> Enum.join(" · ")
  end

  defp filter_by(entries, filters) do
    entries
    |> Enum.filter(fn entry ->
      student_ok =
        case blank_to_nil(filters[:student_name]) do
          nil -> true
          value -> String.downcase(entry.student_name || "") == String.downcase(value)
        end

      date_ok =
        case blank_to_nil(filters[:date]) do
          nil -> true
          value -> entry.date == value
        end

      student_ok and date_ok
    end)
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
