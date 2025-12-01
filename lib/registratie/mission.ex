defmodule Registratie.Mission do
  @moduledoc """
  Opslag en ophalen van de missie-invullijsten per student in CouchDB.
  """

  alias Registratie.Couch

  @db Application.compile_env(:registratie, :missions_db, "missies")

  @fields [
    :leadership_name,
    :asha_value_1,
    :asha_value_2,
    :asha_value_3,
    :asha_value_4,
    :asha_value_5,
    :support_radj,
    :radj_values,
    :group_shared_values,
    :group_different_values,
    :personal_values,
    :lottery_plan,
    :lottery_stop,
    :joy_sources,
    :dream_job,
    :life_story,
    :unclear_values,
    :development_point
  ]

  @sections [
    %{
      title: "Leiderschap",
      intro: "Wie is jullie aanspreekpunt/voortrekker in dit traject? Noteer zijn/haar naam.",
      fields: [
        %{
          name: :leadership_name,
          label: "Naam voorzitter",
          type: :text,
          placeholder: "Bijv. Sara Janssen"
        }
      ]
    },
    %{
      title: "Waarden Stichting Asha",
      intro: "Geef de vijf belangrijkste waarden van Stichting Asha.",
      fields: [
        %{name: :asha_value_1, label: "Waarde 1", type: :text},
        %{name: :asha_value_2, label: "Waarde 2", type: :text},
        %{name: :asha_value_3, label: "Waarde 3", type: :text},
        %{name: :asha_value_4, label: "Waarde 4", type: :text},
        %{name: :asha_value_5, label: "Waarde 5", type: :text}
      ]
    },
    %{
      title: "Waarden en samenwerking",
      fields: [
        %{
          name: :support_radj,
          label: "Hoe zouden jullie Radj kunnen helpen om deze waarden te verwezenlijken?",
          type: :textarea
        },
        %{
          name: :radj_values,
          label: "Welke waarden wil Radj zien in zijn medewerkers denk jij?",
          type: :textarea
        },
        %{
          name: :group_shared_values,
          label: "Gezamenlijke waarden (jullie groep)",
          type: :textarea
        },
        %{
          name: :group_different_values,
          label: "Verschillende waarden",
          type: :textarea
        }
      ]
    },
    %{
      title: "Jouw waarden",
      fields: [
        %{name: :personal_values, label: "Wat is belangrijk voor je?", type: :textarea},
        %{
          name: :lottery_plan,
          label: "Stel je wint de loterij – wat ga je doen?",
          type: :textarea
        },
        %{
          name: :lottery_stop,
          label: "Stel je wint de loterij – wat zou je NIET meer doen?",
          type: :textarea
        },
        %{name: :joy_sources, label: "Waar word je vrolijk van?", type: :textarea},
        %{name: :dream_job, label: "Wat is je droombaan?", type: :textarea},
        %{
          name: :life_story,
          label:
            "Je bent 80 jaar en vertelt: wat was belangrijk, wat heb je gedaan, waar ben je trots op, wat minder geslaagd, wat maakte je gelukkig?",
          type: :textarea
        }
      ]
    },
    %{
      title: "Reflectie op Radj",
      fields: [
        %{
          name: :unclear_values,
          label:
            "Welke waarden van Radj snap je niet of zie je niet terug? Welke voelen abstract of onduidelijk?",
          type: :textarea
        },
        %{
          name: :development_point,
          label: "Wat is je voornaamste ontwikkelpunt? Wat wil je leren of ontwikkelen?",
          type: :textarea
        }
      ]
    }
  ]

  def sections, do: @sections

  def form_data(doc \\ nil) do
    answers = Map.get(doc || %{}, "answers", %{})

    Enum.reduce(@fields, %{}, fn field, acc ->
      value = Map.get(answers, Atom.to_string(field), "")
      Map.put(acc, field, value)
    end)
  end

  def submit(params, user) when is_map(params) do
    student_name = user_name(user)
    normalized = normalize(params)

    with {:ok, id} <- require_student(student_name),
         {:ok, existing} <- fetch(student_name, rescue?: true),
         doc <- build_doc(existing, id, student_name, user, normalized),
         {:ok, saved} <- save_doc(doc, id) do
      {:ok, saved}
    else
      {:error, _} = error -> error
    end
  end

  def fetch(student_name, opts \\ []) when is_binary(student_name) do
    id = doc_id(student_name)
    {:ok, Couch.get_doc(@db, id)}
  rescue
    _ ->
      if Keyword.get(opts, :rescue?, false) do
        {:ok, nil}
      else
        {:error, :not_found}
      end
  end

  def list_all do
    case Couch.list_docs(@db) do
      %{"rows" => rows} ->
        rows
        |> Enum.map(&Map.get(&1, "doc"))
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(&(Map.get(&1, "type") == "mission"))
        |> Enum.sort_by(&String.downcase(Map.get(&1, "student_name", "")))

      _ ->
        []
    end
  rescue
    _ -> []
  end

  defp build_doc(existing, id, student_name, user, answers) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()
    created_at = Map.get(existing || %{}, "created_at") || now
    rev = Map.get(existing || %{}, "_rev")

    %{
      "_id" => id,
      "_rev" => rev,
      "type" => "mission",
      "student_name" => student_name,
      "student_full_name" => full_name(user),
      "answers" => answers,
      "last_submitted_by" => user_name(user),
      "updated_at" => now,
      "created_at" => created_at
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp save_doc(doc, id) do
    case Couch.put_doc(@db, id, doc) do
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

      Map.put(acc, key, normalize_value(value))
    end)
  end

  defp normalize_value(nil), do: ""
  defp normalize_value(value) when is_binary(value), do: String.trim(value)
  defp normalize_value(value), do: value |> to_string() |> String.trim()

  defp require_student(""), do: {:error, "Geen student gevonden in sessie."}
  defp require_student(nil), do: {:error, "Geen student gevonden in sessie."}
  defp require_student(name), do: {:ok, doc_id(name)}

  defp doc_id(student_name), do: "mission-#{student_name}"

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
