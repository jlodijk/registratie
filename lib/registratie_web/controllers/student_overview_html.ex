defmodule RegistratieWeb.StudentOverviewHTML do
  use RegistratieWeb, :html

  embed_templates "student_overview_html/*"

  def format_period(student) do
    start = format_date(student["startDatum"])
    eind = format_date(student["eindDatum"])

    cond do
      start == "" and eind == "" -> "Onbekend"
      true -> "#{start} / #{eind}"
    end
  end

  defp format_date(""), do: ""
  defp format_date(nil), do: ""

  defp format_date(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> Calendar.strftime(date, "%d %b %Y")
      _ -> value
    end
  end
end
