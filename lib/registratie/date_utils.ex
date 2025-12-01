defmodule Registratie.DateUtils do
  @moduledoc """
  Helpers voor datumconversies tussen Europese notatie en ISO (YYYY-MM-DD).
  """

  @eu_regex ~r/^\d{1,2}-\d{1,2}-\d{4}$/
  @iso_regex ~r/^\d{4}-\d{2}-\d{2}$/
  @time_zone "Europe/Amsterdam"

  @doc """
  Zet een invoerwaarde (ISO of Europees) om naar ISO-formaat.
  """
  def iso_from_input(value) do
    value
    |> sanitize()
    |> convert_to_iso()
  end

  @doc """
  Format een waarde naar Europese notatie (dd-mm-jjjj).
  Accepteert zowel ISO- als Europese invoer.
  """
  def display_from_value(value) do
    sanitized = sanitize(value)

    cond do
      sanitized == "" ->
        ""

      Regex.match?(@eu_regex, sanitized) ->
        pad_eu_parts(sanitized)

      true ->
        case Date.from_iso8601(sanitized) do
          {:ok, date} -> format_eu(date)
          _ -> ""
        end
    end
  end

  defp sanitize(nil), do: ""
  defp sanitize(value) when is_binary(value), do: String.trim(value)
  defp sanitize(value), do: value |> to_string() |> String.trim()

  defp convert_to_iso(""), do: ""

  defp convert_to_iso(value) do
    cond do
      Regex.match?(@iso_regex, value) ->
        case Date.from_iso8601(value) do
          {:ok, date} -> Date.to_iso8601(date)
          _ -> ""
        end

      Regex.match?(@eu_regex, value) ->
        convert_eu_to_iso(value)

      true ->
        ""
    end
  end

  defp convert_eu_to_iso(value) do
    case Regex.run(~r/^(\d{1,2})-(\d{1,2})-(\d{4})$/, value) do
      [_, day, month, year] ->
        with {day_int, ""} <- Integer.parse(day),
             {month_int, ""} <- Integer.parse(month),
             {year_int, ""} <- Integer.parse(year),
             {:ok, date} <- Date.new(year_int, month_int, day_int) do
          Date.to_iso8601(date)
        else
          _ -> ""
        end

      _ ->
        ""
    end
  end

  defp format_eu(%Date{} = date) do
    "#{pad(date.day)}-#{pad(date.month)}-#{date.year}"
  end

  defp pad(value) do
    value
    |> Integer.to_string()
    |> String.pad_leading(2, "0")
  end

  defp pad_eu_parts(value) do
    case Regex.run(~r/^(\d{1,2})-(\d{1,2})-(\d{4})$/, value) do
      [_, day, month, year] ->
        "#{pad(String.to_integer(day))}-#{pad(String.to_integer(month))}-#{year}"

      _ ->
        value
    end
  rescue
    ArgumentError ->
      value
  end

  @doc """
  Geeft de datum van vandaag terug als %Date{} in de Amsterdamse tijdzone.
  """
  def today do
    with {:ok, dt} <- DateTime.now(@time_zone) do
      DateTime.to_date(dt)
    else
      {:error, _} -> Date.utc_today()
    end
  end

  @doc """
  Geeft de datum van vandaag terug als ISO (YYYY-MM-DD) string in Amsterdamse tijd.
  """
  def today_iso do
    today() |> Date.to_iso8601()
  end
end
