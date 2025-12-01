defmodule RegistratieWeb.TaskHTML do
  use RegistratieWeb, :html

  alias Registratie.DateUtils

  embed_templates "task_html/*"

  def format_date(nil), do: "Onbekend"
  def format_date(""), do: "Onbekend"

  def format_date(date) do
    case Date.from_iso8601(date) do
      {:ok, d} -> Calendar.strftime(d, "%d-%m-%Y")
      _ -> DateUtils.display_from_value(date) |> fallback_date()
    end
  end

  defp fallback_date(""), do: "Onbekend"
  defp fallback_date(value), do: value
end
