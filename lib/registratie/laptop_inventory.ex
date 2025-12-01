defmodule Registratie.LaptopInventory do
  @moduledoc """
  Opslag en ophalen van laptopinventarisaties in CouchDB (`laptops` database).
  """

  alias Registratie.Couch

  @db Application.compile_env(:registratie, :laptops_db, "laptops")

  @all_fields [
    :student_name,
    :date,
    :hostname,
    :laptop_number,
    :cpu_name,
    :cpu_cores,
    :cpu_threads,
    :cpu_clock,
    :ram_total,
    :ram_type,
    :ram_speed,
    :ram_slots,
    :storage_type,
    :storage_capacity,
    :storage_free,
    :storage_model,
    :gpu_type,
    :gpu_name,
    :gpu_mode,
    :gpu_vram,
    :motherboard_vendor,
    :motherboard_model,
    :bios_version,
    :battery_capacity,
    :battery_health,
    :battery_cycles,
    :wifi_card,
    :ethernet_card,
    :bluetooth_version,
    :ports_usb_a,
    :ports_usb_c,
    :ports_hdmi,
    :ports_audio,
    :ports_sd,
    :display_size,
    :display_resolution,
    :display_panel,
    :display_refresh_rate,
    :audio_card,
    :audio_speakers,
    :audio_microphone,
    :webcam_resolution,
    :webcam_microphone,
    :os_edition,
    :os_version,
    :os_build,
    :os_licensed
  ]

  @type entry :: %{
          required(:data) => map(),
          required(:submitted_at) => String.t(),
          required(:submitted_on) => String.t(),
          required(:submitted_by) => String.t(),
          required(:submitted_by_full_name) => String.t()
        }

  def submit(params, user) when is_map(params) do
    normalized = normalize_params(params)

    with {:ok, hostname} <- require_field(normalized[:hostname], "hostname"),
         :ok <- require_field(normalized[:student_name], "student_name"),
         :ok <- require_field(normalized[:date], "date"),
         {:ok, existing} <- fetch(hostname, rescue?: true),
         :ok <- ensure_second_reviewer(existing, user),
         entry <- build_entry(normalized, user),
         {:ok, doc} <- persist_entry(existing, hostname, entry) do
      {:ok, doc}
    else
      {:error, _} = error -> error
    end
  end

  def fetch(hostname, opts \\ []) do
    try do
      {:ok, Couch.get_doc(@db, hostname)}
    rescue
      _ ->
        if Keyword.get(opts, :rescue?, false), do: {:ok, nil}, else: {:error, :not_found}
    end
  end

  defp persist_entry(nil, hostname, entry) do
    doc =
      %{
        "_id" => hostname,
        "hostname" => hostname,
        "type" => "laptop_inventory",
        "entries" => [entry],
        "status" => "pending_second_review"
      }
      |> put_timestamps()

    save_doc(doc, hostname)
  end

  defp persist_entry(%{"entries" => entries} = doc, hostname, entry) do
    updated_entries = Enum.concat(entries, [entry])

    updated_doc =
      doc
      |> Map.put("entries", updated_entries)
      |> Map.put("status", status_for_entries(updated_entries))
      |> put_timestamps()

    save_doc(updated_doc, hostname)
  end

  defp save_doc(doc, hostname) do
    case Couch.put_doc(@db, hostname, doc) do
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

  defp build_entry(data, user) do
    %{
      "data" => Map.new(data),
      "submitted_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "submitted_on" => Date.utc_today() |> Date.to_iso8601(),
      "submitted_by" => user_name(user),
      "submitted_by_full_name" => full_name(user)
    }
  end

  defp user_name(user) do
    Map.get(user, "name") || Map.get(user, :name) || "onbekend"
  end

  defp full_name(user) do
    [
      Map.get(user, "voornaam") || Map.get(user, :voornaam),
      Map.get(user, "achternaam") || Map.get(user, :achternaam)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> case do
      "" -> user_name(user)
      value -> value
    end
  end

  defp ensure_second_reviewer(nil, _user), do: :ok

  defp ensure_second_reviewer(%{"entries" => entries}, user) when is_list(entries) do
    case entries do
      [first] ->
        current = user_name(user)

        if first["submitted_by"] == current do
          {:error, "Een andere BOL 2 student moet de tweede inventarisatie uitvoeren."}
        else
          :ok
        end

      _ ->
        :ok
    end
  end

  defp ensure_second_reviewer(_, _), do: :ok

  defp status_for_entries(entries) when length(entries) <= 1, do: "pending_second_review"
  defp status_for_entries(_entries), do: "complete"

  defp normalize_params(params) do
    Enum.reduce(@all_fields, %{}, fn field, acc ->
      value =
        Map.get(params, field) ||
          Map.get(params, Atom.to_string(field))

      Map.put(acc, field, normalize_value(value))
    end)
  end

  defp normalize_value(nil), do: ""
  defp normalize_value(value) when is_binary(value), do: String.trim(value)
  defp normalize_value(value), do: to_string(value) |> String.trim()

  defp require_field(value, field) when value in [nil, ""], do: {:error, "#{field} is verplicht."}
  defp require_field(_value, _field), do: :ok

  defp put_timestamps(doc) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    doc
    |> Map.put("updated_at", now)
    |> Map.put_new("created_at", now)
  end
end
