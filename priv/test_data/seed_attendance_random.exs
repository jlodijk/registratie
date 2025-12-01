Mix.Task.run("app.start")

alias Registratie.Couch

attendance_db = Application.fetch_env!(:registratie, :attendance_db)
base_hostname = "hans-odijk-Macmini7-1"
base_bssid = "AC:22:05:25:FA:62"
timezone = "Europe/Amsterdam"

start_date = ~D[2025-11-30]
end_date = ~D[2026-03-22]

weekdays =
  Date.range(start_date, end_date)
  |> Enum.filter(fn date -> Date.day_of_week(date) in 1..5 end)

students = ["AapT", "JanDG"]

:rand.seed(:exsss, :os.timestamp())

make_time = fn hour, minute ->
  {:ok, time} = Time.new(hour, minute, 0)
  time
end

random_login_time = fn ->
  hour = :rand.uniform(3) + 8  # 9..11
  minute = :rand.uniform(60) - 1
  {hour, minute}
end

random_logout_time = fn ->
  hour = :rand.uniform(3) + 14  # 15..17
  max_minute = if hour == 17, do: 24, else: 60
  minute = :rand.uniform(max_minute) - 1
  {hour, minute}
end

build_doc = fn name, %DateTime{} = dt, event ->
  %{
    "_id" => "aanwezig-#{name}-#{Date.to_iso8601(DateTime.to_date(dt))}-#{Time.to_iso8601(DateTime.to_time(dt))}-rand-#{System.unique_integer([:positive])}",
    "type" => "aanwezig",
    "name" => name,
    "tijd" => DateTime.to_iso8601(dt),
    "datum" => Date.to_iso8601(DateTime.to_date(dt)),
    "tijd_local" => Time.to_iso8601(DateTime.to_time(dt)),
    "event" => event,
    "hostname" => base_hostname,
    "bssid" => base_bssid,
    "platform" => "seed-random"
  }
end

Enum.each(students, fn student ->
  Enum.each(weekdays, fn date ->
    # login + logout for each weekday
    {login_hour, login_minute} = random_login_time.()
    login_time = make_time.(login_hour, login_minute)
    {:ok, login_dt} = DateTime.new(date, login_time, timezone)

    {logout_hour, logout_minute} = random_logout_time.()
    logout_time = make_time.(logout_hour, logout_minute)
    {:ok, logout_dt} = DateTime.new(date, logout_time, timezone)

    for doc <- [build_doc.(student, login_dt, "login"), build_doc.(student, logout_dt, "logout")] do
      case Couch.create_doc(attendance_db, doc) do
        %{"ok" => true} -> IO.puts("Toegevoegd: #{doc["_id"]}")
        other -> IO.inspect(other, label: "Fout bij #{doc["_id"]}")
      end
    end
  end)
end)
