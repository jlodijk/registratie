defmodule Registratie.OaseRules do
  @moduledoc """
  Haalt algemene OASE-regels op uit CouchDB zodat we ze kunnen tonen in het aanwezigheidsoverzicht.
  """

  alias Registratie.Couch

  @rules_db Application.compile_env(:registratie, :oase_rules_db, "oaseRegels")
  @rules_doc_id Application.compile_env(:registratie, :oase_rules_doc_id, "oaseRegels")

  @spec fetch_rules() :: %{werktijd: String.t() | nil, aanwezigheid: [String.t()]}
  def fetch_rules do
    with {:ok, doc} <- load_rules_doc() do
      %{
        werktijd: extract(doc, "werktijd"),
        aanwezigheid: extract(doc, "aanwezigheid") |> List.wrap() |> normalize_list()
      }
    else
      _ -> %{werktijd: nil, aanwezigheid: []}
    end
  end

  defp extract(map, key) when is_map(map) do
    map[key] ||
      case safe_to_existing_atom(key) do
        nil -> nil
        atom_key -> map[atom_key]
      end
  end

  defp extract(_, _), do: nil

  defp normalize_list(values) when is_list(values) do
    values
    |> Enum.map(&normalize_text/1)
    |> Enum.reject(&(&1 in [nil, ""]))
  end

  defp normalize_list(_), do: []

  defp normalize_text(nil), do: nil
  defp normalize_text(value) when is_binary(value), do: String.trim(value)

  defp normalize_text(value) do
    value
    |> to_string()
    |> String.trim()
  end

  defp safe_to_existing_atom(key) when is_atom(key), do: key

  defp safe_to_existing_atom(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end

  defp safe_to_existing_atom(_), do: nil

  defp load_rules_doc do
    @rules_db
    |> db_candidates()
    |> Enum.find_value(&fetch_doc_from_db/1)
    |> case do
      {:ok, doc} -> {:ok, doc}
      _ -> {:error, :not_found}
    end
  end

  defp fetch_doc_from_db(db) do
    case Couch.get_doc(db, @rules_doc_id) do
      %{"error" => _} -> nil
      %{"reason" => _} -> nil
      doc -> {:ok, doc}
    end
  rescue
    _ -> nil
  end

  defp db_candidates(db) when is_binary(db) do
    trimmed = String.trim(db)
    Enum.uniq([trimmed, String.downcase(trimmed)])
  end

  defp db_candidates(_), do: ["oaseRegels", "oaseregels"]
end
