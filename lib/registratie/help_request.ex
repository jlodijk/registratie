defmodule Registratie.HelpRequest do
  @moduledoc """
  Opslag en ophalen van hulpvragen die studenten invullen voor bezoekers van het buurthuis.
  """

  alias Registratie.Couch

  @db Application.compile_env(:registratie, :help_requests_db, "hulpvragen")

  @fields [
    :customer_first_name,
    :category,
    :device_type,
    :question,
    :solution,
    :escalated,
    :followup_when,
    :followup_notes,
    :status,
    :feedback
  ]

  @required [:customer_first_name, :question, :solution]

  def submit(params, user) when is_map(params) do
    data = normalize(params)
    student = user_name(user)

    with {:student, false} <- {:student, student in [nil, ""]},
         :ok <- validate_required(data),
         :ok <- validate_followup(data),
         doc <- build_doc(data, user),
         {:ok, saved} <- save_doc(doc) do
      {:ok, saved}
    else
      {:student, true} -> {:error, "Geen student gevonden in sessie."}
      {:error, _} = error -> error
    end
  end

  def list_for_student(student_name, opts \\ []) do
    status_filter = Keyword.get(opts, :status)

    case Couch.list_docs(@db) do
      %{"rows" => rows} ->
        rows
        |> Enum.map(&Map.get(&1, "doc"))
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(&(Map.get(&1, "type") == "help_request"))
        |> Enum.filter(&(Map.get(&1, "submitted_by") == student_name))
        |> maybe_filter_status(status_filter)
        |> Enum.sort_by(&Map.get(&1, "created_at", ""), {:desc, String})

      _ ->
        []
    end
  rescue
    _ -> []
  end

  def list_all(opts \\ []) do
    status_filter = Keyword.get(opts, :status)

    case Couch.list_docs(@db) do
      %{"rows" => rows} ->
        rows
        |> Enum.map(&Map.get(&1, "doc"))
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(&(Map.get(&1, "type") == "help_request"))
        |> maybe_filter_status(status_filter)
        |> Enum.sort_by(&Map.get(&1, "created_at", ""), {:desc, String})

      _ ->
        []
    end
  rescue
    _ -> []
  end

  def update_status(id, status, user) do
    new_status = normalize_status(status)

    with {:ok, doc} <- fetch(id),
         :ok <- ensure_owner(doc, user),
         updated <- doc |> Map.put("status", new_status) |> put_timestamps() |> Map.delete(:__id),
         {:ok, saved} <- save_doc(updated) do
      {:ok, saved}
    else
      {:error, _} = error -> error
    end
  end

  def add_feedback(id, params, user) do
    category =
      params
      |> Map.get("feedback_category", "")
      |> to_string()
      |> String.trim()

    comment =
      params
      |> Map.get("feedback_comment", "")
      |> to_string()
      |> String.trim()

    with :ok <- require_feedback_category(category),
         {:ok, doc} <- fetch(id),
         entry <- build_feedback_entry(category, comment, user),
         updated <-
           doc
           |> append_feedback(entry)
           |> put_timestamps()
           |> Map.delete(:__id),
         {:ok, saved} <- save_doc(updated) do
      {:ok, saved}
    else
      {:error, _} = error -> error
    end
  end

  def fetch(id) do
    {:ok, Couch.get_doc(@db, id)}
  rescue
    _ -> {:error, :not_found}
  end

  defp ensure_owner(%{"submitted_by" => owner}, user) do
    if owner == user_name(user) do
      :ok
    else
      {:error, "Je kunt alleen je eigen hulpvragen bijwerken."}
    end
  end

  defp ensure_owner(_, _), do: {:error, "Je kunt alleen je eigen hulpvragen bijwerken."}

  defp maybe_filter_status(list, nil), do: list
  defp maybe_filter_status(list, ""), do: list

  defp maybe_filter_status(list, status) do
    status = normalize_status(status)
    Enum.filter(list, &(Map.get(&1, "status") == status))
  end

  defp build_doc(data, user) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()
    id = unique_id()
    escalated = data[:escalated] == "ja"

    %{
      "_id" => id,
      "type" => "help_request",
      "customer_first_name" => data[:customer_first_name],
      "category" => data[:category],
      "device_type" => data[:device_type],
      "question" => data[:question],
      "solution" => data[:solution],
      "escalated" => escalated,
      "followup_when" => data[:followup_when],
      "followup_notes" => data[:followup_notes],
      "status" => normalize_status(Map.get(data, :status)),
      "submitted_by" => user_name(user),
      "submitted_by_full_name" => full_name(user),
      "feedback" => [],
      "created_at" => now,
      "updated_at" => now
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp save_doc(doc) do
    case Couch.put_doc(@db, doc["_id"], doc) do
      %{"ok" => true, "rev" => rev} ->
        {:ok, Map.put(doc, "_rev", rev)}

      %{"ok" => true} ->
        {:ok, doc}

      %{"error" => error, "reason" => reason} ->
        {:error, "#{error}: #{reason}"}

      other ->
        {:error, "Onbekend antwoord van CouchDB: #{inspect(other)}"}
    end
  rescue
    exception -> {:error, Exception.message(exception)}
  end

  defp normalize(params) do
    Enum.reduce(@fields, %{}, fn field, acc ->
      key = Atom.to_string(field)

      value =
        Map.get(params, field) ||
          Map.get(params, key) ||
          ""

      Map.put(acc, field, normalize_value(value))
    end)
  end

  defp normalize_value(nil), do: ""
  defp normalize_value(value) when is_binary(value), do: String.trim(value)
  defp normalize_value(value), do: value |> to_string() |> String.trim()

  defp validate_required(data) do
    missing =
      Enum.filter(@required, fn field ->
        Map.get(data, field, "") in ["", nil]
      end)

    case missing do
      [] -> :ok
      [first | _] -> {:error, "#{humanize(first)} is verplicht."}
    end
  end

  defp validate_followup(%{escalated: escalated, followup_when: followup_when}) do
    if escalated == "ja" and followup_when in ["", nil] do
      {:error, "Vervolgafspraak is verplicht bij escalatie."}
    else
      :ok
    end
  end

  defp validate_followup(_), do: :ok

  defp normalize_status(nil), do: "open"
  defp normalize_status(""), do: "open"

  defp normalize_status(status) do
    status
    |> to_string()
    |> String.downcase()
    |> case do
      "afgerond" -> "afgerond"
      _ -> "open"
    end
  end

  defp unique_id do
    timestamp = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
    "help-#{timestamp}"
  end

  defp require_feedback_category(""), do: {:error, "Kies een beoordelingscategorie."}
  defp require_feedback_category(nil), do: {:error, "Kies een beoordelingscategorie."}
  defp require_feedback_category(_), do: :ok

  defp build_feedback_entry(category, comment, user) do
    %{
      "category" => category,
      "comment" => comment,
      "by" => user_name(user),
      "by_full_name" => full_name(user),
      "at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp append_feedback(doc, entry) do
    current =
      doc
      |> Map.get("feedback")
      |> case do
        list when is_list(list) -> list
        _ -> []
      end

    Map.put(doc, "feedback", current ++ [entry])
  end

  defp humanize(field) do
    field
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp put_timestamps(doc) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    doc
    |> Map.put("updated_at", now)
    |> Map.put_new("created_at", now)
  end

  defp user_name(user) do
    Map.get(user || %{}, "name") || Map.get(user || %{}, :name) || ""
  end

  defp full_name(user) do
    [
      Map.get(user || %{}, "voornaam") || Map.get(user || %{}, :voornaam),
      Map.get(user || %{}, "achternaam") || Map.get(user || %{}, :achternaam)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> case do
      "" -> user_name(user)
      value -> value
    end
  end
end
