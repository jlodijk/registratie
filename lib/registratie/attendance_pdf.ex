defmodule Registratie.AttendancePdf do
  @moduledoc """
  Eenvoudige PDF-generator voor aanwezigheidsrapporten.
  """

  @page_width 595
  @page_height 842
  @margin 40
  @line_height 16

  def render(%{rows: _rows} = report) do
    lines = build_lines(report)
    content = build_content(lines)
    {:ok, build_pdf(content)}
  rescue
    exception -> {:error, Exception.message(exception)}
  end

  defp build_lines(%{rows: rows} = report) do
    student_name = Map.get(report.student, "name") || "onbekend"
    stage_days =
      report.student
      |> Map.get("stageDagen", [])
      |> List.wrap()
      |> Enum.join(", ")
      |> case do
        "" -> "Onbekend"
        other -> other
      end

    header = [
      "Aanwezigheid #{student_name}",
      "Toegestane stagedagen: #{stage_days}",
      ""
    ]

    table_header = [
      pad("Datum", 14),
      pad("Dag", 12),
      pad("In", 8),
      pad("Uit", 8),
      pad("Uren", 6),
      "Boodschap"
    ]

    table_lines =
      rows
      |> Enum.map(fn row ->
        [
          pad(row.date_label, 14),
          pad(row.weekday || "", 12),
          pad(row.first_login, 8),
          pad(row.last_logout, 8),
          pad(row.hours_label, 6),
          truncate(row.message || "", 60)
        ]
        |> Enum.join("  ")
      end)

    totals = [
      "",
      "Totaal aanwezig: #{report.total_label} uur"
    ]

    header ++ [Enum.join(table_header, "  ")] ++ table_lines ++ totals
  end

  defp build_content(lines) do
    # Use monospaced font so padded columns line up.
    header = "BT\n/F1 10 Tf\n#{@line_height} TL\n#{@margin} #{@page_height - @margin} Td\n"
    body = Enum.map_join(lines, "", fn line -> "(" <> escape_text(line) <> ") Tj\nT*\n" end)
    header <> body <> "ET\n"
  end

  defp build_pdf(content) do
    length = byte_size(content)

    objects = [
      {"<< /Type /Catalog /Pages 2 0 R >>"},
      {"<< /Type /Pages /Kids [3 0 R] /Count 1 /MediaBox [0 0 #{@page_width} #{@page_height}] >>"},
      {"<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>"},
      {"<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>"},
      {"<< /Length #{length} >>\nstream\n#{content}\nendstream"}
    ]

    serialize(objects)
  end

  defp serialize(objects) do
    header = "%PDF-1.4\n"
    {body_parts, offsets, _} =
      Enum.reduce(objects, {[], [], byte_size(header)}, fn {obj}, {acc, offs, offset} ->
        index = length(acc) + 1
        obj_str = "#{index} 0 obj\n#{obj}\nendobj\n"
        {[obj_str | acc], [offset | offs], offset + byte_size(obj_str)}
      end)

    body_binary = body_parts |> Enum.reverse() |> IO.iodata_to_binary()

    xref_entries =
      ["0000000000 65535 f \n" | Enum.map(Enum.reverse(offsets), fn offset ->
          :io_lib.format("~10..0B 00000 n \n", [offset]) |> IO.iodata_to_binary()
        end)]

    xref = [
      "xref\n0 #{length(objects) + 1}\n",
      xref_entries,
      "trailer << /Size #{length(objects) + 1} /Root 1 0 R >>\n",
      "startxref\n",
      Integer.to_string(byte_size(header <> body_binary)),
      "\n%%EOF"
    ]
    |> IO.iodata_to_binary()

    header <> body_binary <> xref
  end

  defp escape_text(text) do
    text
    |> to_string()
    |> String.replace("\\", "\\\\")
    |> String.replace("(", "\\(")
    |> String.replace(")", "\\)")
  end

  defp pad(value, count) do
    value
    |> to_string()
    |> String.pad_trailing(count)
  end

  defp truncate(value, max) do
    value
    |> to_string()
    |> case do
      str when byte_size(str) <= max -> str
      str -> binary_part(str, 0, max - 3) <> "..."
    end
  end
end
