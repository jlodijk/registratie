defmodule RegistratieWeb.LaptopInventoryHTML do
  use RegistratieWeb, :html

  embed_templates "laptop_inventory_html/*"

  @month_names ~w(jan feb mrt apr mei jun jul aug sep okt nov dec)

  def format_eu_date(nil), do: ""

  def format_eu_date(%Date{} = date) do
    month = Enum.at(@month_names, date.month - 1)
    "#{date.day} #{month} #{date.year}"
  end

  def format_eu_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> format_eu_date(date)
      _ -> value
    end
  end

  def format_eu_date(_), do: ""
end
