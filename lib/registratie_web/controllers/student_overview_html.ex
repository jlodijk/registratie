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
      {:ok, date} -> format_dutch(date)
      _ -> value
    end
  end

  @month_abbr %{
    1 => "JAN",
    2 => "FEB",
    3 => "MRT",
    4 => "APR",
    5 => "MEI",
    6 => "JUN",
    7 => "JUL",
    8 => "AUG",
    9 => "SEP",
    10 => "OKT",
    11 => "NOV",
    12 => "DEC"
  }

  defp format_dutch(%Date{day: day, month: month, year: year}) do
    month_abbr = Map.get(@month_abbr, month, "")
    "#{pad(day)} #{month_abbr} #{year}"
  end

  defp pad(value), do: value |> Integer.to_string() |> String.pad_leading(2, "0")
end
