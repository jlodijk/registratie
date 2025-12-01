defmodule RegistratieWeb.MissionHTML do
  use RegistratieWeb, :html

  embed_templates "mission_html/*"

  def value_for(submission, field) do
    submission
    |> Map.get("answers", %{})
    |> Map.get(Atom.to_string(field), "")
  end

  def format_timestamp(nil), do: "Nog niet ingevuld"
  def format_timestamp(""), do: "Nog niet ingevuld"

  def format_timestamp(iso) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _offset} -> Calendar.strftime(dt, "%d-%m-%Y %H:%M")
      _ -> iso
    end
  end
end
