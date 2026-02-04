defmodule RegistratieWeb.StudentHTML do
  use RegistratieWeb, :html

  alias Registratie.DateUtils

  embed_templates "student_html/*"

  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :required, :boolean, default: false

  def date_picker(assigns) do
    assigns =
      assigns
      |> assign(:display_value, DateUtils.display_from_value(assigns.field.value))
      |> assign(:iso_value, DateUtils.iso_from_input(assigns.field.value))

    ~H"""
    <div
      class="space-y-2"
      phx-hook="EuDatePicker"
      id={"#{@field.id}-wrapper"}
    >
      <.label for={"#{@field.id}-display"}>{@label}</.label>
      <div class="flex gap-2">
        <input
          type="text"
          id={"#{@field.id}-display"}
          value={@display_value}
          placeholder="dd-mm-yyyy"
          inputmode="numeric"
          pattern="\d{2}-\d{2}-\d{4}"
          class="flex-1 rounded-lg border border-zinc-300 px-3 py-2 text-sm text-zinc-900 focus:border-zinc-400 focus:outline-none"
          data-role="display"
          lang="nl"
          autocomplete="off"
          required={@required}
        />
        <button
          type="button"
          data-role="trigger"
          class="rounded-lg border border-zinc-300 px-3 py-2 text-sm font-semibold text-zinc-700 hover:bg-zinc-100"
        >
          Kalender
        </button>
      </div>
      <input
        type="date"
        id={@field.id}
        name={@field.name}
        value={@iso_value}
        data-role="hidden"
        lang="nl"
        required={@required}
        style="position: absolute; width: 1px; height: 1px; opacity: 0; pointer-events: none;"
      />
    </div>
    """
  end
end
