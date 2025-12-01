Mix.Task.run("app.start")

alias Registratie.Couch

attendance_db = Application.fetch_env!(:registratie, :attendance_db)
base_hostname = "hans-odijk-Macmini7-1"
base_bssid = "AC:22:05:25:FA:62"
timezone = "Europe/Amsterdam"

entries = [
  %{name: "AapT", date: "2025-12-01", time: "09:42", event: "login", bssid: "AC:22:05:25:FA:11"},
  %{name: "AapT", date: "2025-12-01", time: "17:54", event: "logout", bssid: "AC:22:05:25:FA:11"},
  %{name: "AapT", date: "2025-12-02", time: "08:14", event: "login"},
  %{name: "AapT", date: "2025-12-02", time: "16:12", event: "login"},
  %{name: "AapT", date: "2025-12-03", time: "08:14", event: "login"},
  %{name: "AapT", date: "2025-12-03", time: "16:12", event: "login"},
  %{name: "JanDG", date: "2025-12-01", time: "09:42", event: "login"},
  %{name: "JanDG", date: "2025-12-01", time: "17:54", event: "logout"},
  %{name: "JanDG", date: "2025-12-02", time: "10:14", event: "login"},
  %{name: "JanDG", date: "2025-12-02", time: "16:12", event: "login"},
  %{name: "JanDG", date: "2025-12-03", time: "08:14", event: "login"},
  %{name: "JanDG", date: "2025-12-03", time: "16:12", event: "login"}
]

for entry <- entries do
  {:ok, date} = Date.from_iso8601(entry.date)
  {:ok, time} = Time.from_iso8601(entry.time <> ":00")
  {:ok, datetime} = DateTime.new(date, time, timezone)

  doc = %{
    "_id" => "aanwezig-#{entry.name}-#{entry.date}-#{entry.time}-seed",
    "type" => "aanwezig",
    "name" => entry.name,
    "tijd" => DateTime.to_iso8601(datetime),
    "datum" => Date.to_iso8601(date),
    "tijd_local" => Time.to_iso8601(time),
    "event" => entry.event,
    "hostname" => entry[:hostname] || base_hostname,
    "bssid" => String.upcase(entry[:bssid] || base_bssid),
    "platform" => "seed"
  }

  case Couch.create_doc(attendance_db, doc) do
    %{"ok" => true} -> IO.puts("Toegevoegd: #{doc["_id"]}")
    other -> IO.inspect(other, label: "Fout bij #{doc["_id"]}")
  end
end
