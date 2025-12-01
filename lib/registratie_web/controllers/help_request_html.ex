defmodule RegistratieWeb.HelpRequestHTML do
  use RegistratieWeb, :html

  embed_templates "help_request_html/*"

  def format_timestamp(nil), do: ""
  def format_timestamp(""), do: ""

  def format_timestamp(iso) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _} -> Calendar.strftime(dt, "%d-%m-%Y %H:%M")
      _ -> iso
    end
  end

  def status_badge("afgerond"), do: {"bg-emerald-50 text-emerald-700 border-emerald-200", "Afgerond"}
  def status_badge(_), do: {"bg-amber-50 text-amber-700 border-amber-200", "Open"}

  def device_display(value) when value in [nil, ""], do: "Onbekend"
  def device_display(value), do: value
end
