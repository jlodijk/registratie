defmodule Registratie.StandardTasks do
  @moduledoc """
  Beheer van standaardtaken (datalist) voor het takenformulier.
  Data wordt opgeslagen in de `taken` database met document-id
  `template_standaard_taken`.
  """

  alias Registratie.Couch

  @db "standaard_taken"
  @doc_id "template_standaard_taken"

  @default_tasks [
    "Upload stageverslag in OASE",
    "Lever laptop en oplader in",
    "Plan voortgangsgesprek met begeleider",
    "Update weekplanning",
    "Controleer aanwezigheid in registratiesysteem"
  ]

  @doc """
  Haalt de lijst met standaardtaken op. Valt terug op een vaste set wanneer
  het document nog niet bestaat.
  """
  def list do
    case fetch_doc() do
      {:ok, doc} -> tasks_from_doc(doc)
      _ -> @default_tasks
    end
  rescue
    _ -> @default_tasks
  end

  @doc """
  Voegt een taak toe aan de standaardlijst.
  """
  def add(task) do
    normalized = normalize_task(task)

    if normalized == "" do
      {:error, "Taak mag niet leeg zijn."}
    else
      with {tasks, doc} <- load_tasks_with_doc(),
           false <- normalized in tasks do
        tasks
        |> Enum.concat([normalized])
        |> save_tasks(doc)
      else
        true -> {:error, "Taak bestaat al in de standaardlijst."}
        {:error, reason} -> {:error, reason}
      end
    end
  rescue
    exception -> {:error, Exception.message(exception)}
  end

  @doc """
  Verwijdert een taak uit de standaardlijst.
  """
  def remove(task) do
    normalized = normalize_task(task)
    {tasks, doc} = load_tasks_with_doc()

    filtered = Enum.reject(tasks, &(&1 == normalized))

    case length(filtered) == length(tasks) do
      true -> {:error, "Taak niet gevonden."}
      false -> save_tasks(filtered, doc)
    end
  rescue
    exception -> {:error, Exception.message(exception)}
  end

  defp load_tasks_with_doc do
    case fetch_doc() do
      {:ok, doc} -> {tasks_from_doc(doc), doc}
      _ -> {@default_tasks, %{"_id" => @doc_id}}
    end
  end

  defp tasks_from_doc(%{"taken" => list}) when is_list(list) do
    list
    |> Enum.map(&normalize_task/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp tasks_from_doc(%{"taak" => taak}) when is_binary(taak) do
    taak
    |> String.split(~r/[\r\n]+/, trim: true)
    |> Enum.map(&normalize_task/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp tasks_from_doc(_), do: @default_tasks

  defp save_tasks(tasks, existing_doc) do
    payload =
      %{
        "_id" => @doc_id,
        "type" => Map.get(existing_doc, "type") || "template_standaard_taken",
        "taken" => tasks
      }
      |> maybe_put_rev(existing_doc)

    case Couch.put_doc(@db, @doc_id, payload) do
      %{"ok" => true} -> {:ok, tasks}
      %{"error" => error, "reason" => reason} -> {:error, "#{error}: #{reason}"}
      other -> {:error, "Onbekend antwoord: #{inspect(other)}"}
    end
  end

  defp fetch_doc do
    {:ok, Couch.get_doc(@db, @doc_id)}
  rescue
    _ -> :error
  end

  defp maybe_put_rev(payload, %{"_rev" => rev}) when is_binary(rev),
    do: Map.put(payload, "_rev", rev)

  defp maybe_put_rev(payload, _), do: payload

  defp normalize_task(task) do
    task
    |> to_string()
    |> String.trim()
  end
end
