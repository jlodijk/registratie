defmodule Registratie.Student do
  @moduledoc """
  Representatie en validatie van een studentdocument voor CouchDB.
  Geen Ecto, puur JSON-based.
  """

  alias Registratie.DateUtils

  @type t :: %{
          _id: String.t(),
          type: String.t(),
          name: String.t(),
          voornaam: String.t(),
          achternaam: String.t(),
          email: String.t(),
          opleiding: String.t(),
          mobiel: String.t(),
          woonplaats: String.t(),
          postcode: String.t(),
          hostname: String.t(),
          startDatum: String.t(),
          eindDatum: String.t(),
          status: String.t(),
          created_at: String.t(),
          updated_at: String.t(),
          stageDagen: [String.t()],
          opmerkingen: list()
        }

  # 🧩 standaard template voor een nieuwe student
  @default_fields %{
    type: "student",
    voornaam: "",
    achternaam: "",
    email: "",
    opleiding: "",
    mobiel: "",
    woonplaats: "",
    postcode: "",
    hostname: "",
    startDatum: "",
    eindDatum: "",
    status: "",
    stageDagen: ["ma", "di", "wo", "do", "vr"],
    opmerkingen: [],
    created_at: "",
    updated_at: ""
  }

  @doc """
  Bouwt een geldig studentdocument op basis van de ingevoerde `name`.
  `_id` wordt automatisch gelijk aan `name`.
  `created_at` en `updated_at` worden automatisch ingevuld (ISO-datum).
  """
  def new(attrs, role) when is_map(attrs) do
    now = current_date()
    name = Map.get(attrs, :name) || Map.get(attrs, "name")

    case validate_name(name) do
      :ok ->
        student =
          @default_fields
          |> Map.merge(attrs)
          |> Map.put(:name, name)
          |> Map.put(:_id, name)
          |> put_timestamps(now)
          |> ensure_created_timestamp()

        validate_role(role, student)

      {:error, msg} ->
        {:error, msg}
    end
  end

  # ✅ update: alleen updated_at aanpassen
  def update(existing_student, updates, role) do
    now = current_date()

    updated =
      existing_student
      |> Map.merge(updates)
      |> Map.put(:updated_at, now)
      |> Map.put(:"updated-at", now)
      |> ensure_created_timestamp()

    validate_role(role, updated)
  end

  # 🔍 valideer dat name geldig is
  defp validate_name(nil), do: {:error, "Gebruikersnaam is verplicht."}
  defp validate_name(""), do: {:error, "Gebruikersnaam is verplicht."}

  defp validate_name(name) when is_binary(name) do
    len = String.length(name)

    cond do
      len < 4 -> {:error, "Gebruikersnaam moet minimaal 4 tekens bevatten."}
      len > 5 -> {:error, "Gebruikersnaam mag maximaal 5 tekens bevatten."}
      true -> :ok
    end
  end

  # 🔒 valideer rol: wie mag wat
  defp validate_role("begeleider", student) do
    # begeleider mag nieuwe student maken
    {:ok, student}
  end

  defp validate_role("student", student) do
    # student mag alleen eigen gegevens wijzigen
    {:ok, student}
  end

  defp validate_role(_, _student), do: {:error, "ongeldige rol"}

  defp current_date, do: DateUtils.today_iso()

  defp put_timestamps(student, now) do
    student
    |> Map.put(:created_at, now)
    |> Map.put(:updated_at, now)
  end

  defp ensure_created_timestamp(student) do
    updated = Map.get(student, :updated_at) || current_date()
    created = Map.get(student, :created_at) || updated

    student
    |> Map.put(:created_at, created)
    |> Map.put(:updated_at, updated)
  end
end
