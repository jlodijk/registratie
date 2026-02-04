defmodule RegistratieWeb.LoginController do
  use RegistratieWeb, :controller
  require Logger
  alias Registratie.{Attendance, Auth, Couch, DateUtils}

  # GET /login — toon inlogpagina
  def new(conn, _params) do
    conn
    |> maybe_capture_client_metadata()
    |> render(:new, page_title: "Login")
  end

  def login(conn, _params) do
    render(conn, :login, page_title: "Login")
  end

  # POST /login — verwerk inlogformulier
  def create(conn, %{"username" => username, "password" => password} = params) do
    conn = maybe_capture_client_metadata(conn, params)
    metadata = session_metadata(conn)

    Logger.info("""
    login capture: params_hostname=#{inspect(params["hostname"])} params_ssid=#{inspect(pick_ssid(params))}
    session_hostname=#{inspect(get_session(conn, :client_hostname))} session_ssid=#{inspect(get_session(conn, :client_ssid))}
    metadata_hostname=#{inspect(metadata.hostname)} metadata_ssid=#{inspect(metadata.ssid)}
    """)

    Logger.info("attendance check payload: stored_hostname=#{inspect(get_session(conn, :current_user) && get_session(conn, :current_user)["hostname"])} incoming_hostname=#{inspect(metadata.hostname)}")

    log_client_hostname(username, metadata)

    case Auth.authenticate(username, password) do
      {:ok, user_ctx} ->
        first_password? = first_password_required?(username)
        student_profile = load_student_profile(user_ctx, metadata)

        user_session =
          user_ctx
          |> Map.merge(student_profile)
          |> normalize_roles()
          |> Map.put("firstPassword", first_password?)

        conn
        |> configure_session(renew: true)
        |> put_session(:current_user, user_session)
        |> log_attendance(:login, user_session, metadata)
        |> redirect_after_login(first_password?, user_session)

      {:error, :invalid_credentials} ->
        conn
        |> put_flash(:error, "Onjuiste gebruikersnaam of wachtwoord")
        |> redirect(to: ~p"/login")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Login mislukt: #{inspect(reason)}")
        |> redirect(to: ~p"/login")
    end
  end

  # GET /logout
  def delete(conn, _params) do
    conn
    |> log_attendance(:logout, get_session(conn, :current_user), session_metadata(conn))
    |> configure_session(drop: true)
    |> put_flash(:info, "Je bent uitgelogd.")
    |> redirect(to: ~p"/login")
  end

  def logout(conn, _params) do
    conn
    |> log_attendance(:logout, get_session(conn, :current_user), session_metadata(conn))
    |> configure_session(drop: true)
    |> put_flash(:info, "Je bent uitgelogd.")
    |> redirect(to: "/login")
  end

  defp first_password_required?(username) do
    doc_id = "org.couchdb.user:#{username}"

    case Couch.get_doc("_users", doc_id) do
      %{"firstPassword" => true} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  defp redirect_after_login(conn, true, user_session) do
    conn
    |> put_flash(:info, "Stel eerst een persoonlijk wachtwoord in.")
    |> assign(:current_user, user_session)
    |> redirect(to: ~p"/password/nieuw")
  end

  defp redirect_after_login(conn, false, user_session) do
    conn
    |> put_flash(:info, "Welkom #{user_session["name"]}!")
    |> redirect(to: ~p"/home")
  end

  defp session_metadata(conn) do
    %{
      hostname: get_session(conn, :client_hostname) || conn.params["hostname"],
      ssid: get_session(conn, :client_ssid) || pick_ssid(conn.params),
      bssid: get_session(conn, :client_bssid) || conn.params["bssid"],
      platform: user_agent(conn)
    }
  end

  defp maybe_capture_client_metadata(conn) do
    maybe_capture_client_metadata(conn, conn.params)
  end

  defp maybe_capture_client_metadata(conn, nil) do
    maybe_capture_client_metadata(conn, conn.params)
  end

  defp maybe_capture_client_metadata(conn, params) do
    conn
    |> maybe_put_metadata(:client_hostname, params["hostname"])
    |> maybe_put_metadata(:client_ssid, pick_ssid(params))
    |> maybe_put_metadata(:client_bssid, params["bssid"])
  end

  defp pick_ssid(params) when is_map(params) do
    params["network"] || params["netwerk"] || params["ssid"]
  end

  defp pick_ssid(_), do: nil

  defp maybe_put_metadata(conn, _key, nil), do: conn

  defp maybe_put_metadata(conn, key, value) do
    case sanitize_client_field(value) do
      nil -> conn
      sanitized -> put_session(conn, key, sanitized)
    end
  end

  defp sanitize_client_field(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp sanitize_client_field(_), do: nil

  defp user_agent(conn) do
    conn
    |> get_req_header("user-agent")
    |> List.first()
  end

  defp log_attendance(conn, _event, nil, _metadata), do: conn

  defp log_attendance(conn, :login, user_session, metadata) do
    case Attendance.log_login(user_session, metadata) do
      :ok ->
        conn

      {:error, reason} ->
        conn
        |> put_flash(:error, human_reason(reason, user_session, metadata))
    end
  end

  defp log_attendance(conn, :logout, user_session, metadata) do
    # Geen flash bij logout; stille fout is ok.
    Attendance.log_logout(user_session, metadata)
    conn
  end

  defp log_client_hostname(username, %{hostname: hostname} = metadata) do
    Logger.info(
      "Login metadata for #{username}: hostname=#{inspect(hostname)}, ssid=#{inspect(metadata.ssid)}, bssid=#{inspect(metadata.bssid)}, platform=#{inspect(metadata.platform)}"
    )
  end

  defp log_client_hostname(_username, _metadata), do: :ok

  defp normalize_roles(%{"roles" => roles} = user_ctx) when is_list(roles) do
    normalized =
      roles
      |> Enum.flat_map(fn
        "_admin" -> ["_admin", "admin"]
        other -> [other]
      end)
      |> Enum.map(&to_string/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    Map.put(user_ctx, "roles", normalized)
  end

  defp normalize_roles(user_ctx) when is_map(user_ctx) do
    Map.put_new(user_ctx, "roles", [])
  end

  defp normalize_roles(_), do: %{"roles" => []}

  defp load_student_profile(%{"name" => name}, metadata) do
    {doc, doc_id} = fetch_student_doc(name)
    maybe_fill_hostname(doc, metadata, doc_id || name)
  end

  defp load_student_profile(_user_ctx, _metadata), do: %{}

  defp fetch_student_doc(name) do
    with nil <- fetch_doc(name),
         downcased <- String.downcase(name),
         nil <- if(downcased != name, do: fetch_doc(downcased), else: nil) do
      {nil, nil}
    else
      {doc, id} -> {doc, id}
      nil -> {nil, nil}
    end
  end

  defp fetch_doc(id) when is_binary(id) do
    {Couch.get_doc("studenten", id), id}
  rescue
    _ -> nil
  end

  defp maybe_fill_hostname(nil, _metadata, _doc_id), do: %{}

  defp maybe_fill_hostname(doc, metadata, doc_id) when is_map(doc) do
    current = Map.get(doc, "hostname", "")
    existing = normalize_hostname(current)
    incoming = normalize_hostname(Map.get(metadata, :hostname))

    cond do
      existing != "" ->
        doc

      incoming == "" ->
        doc

      true ->
        updates = %{
          "hostname" => incoming,
          "updated_at" => DateUtils.today_iso()
        }

        doc
        |> persist_hostname(doc_id, updates)
        |> Map.merge(updates)
    end
  end

  defp maybe_fill_hostname(doc, _metadata, _doc_id), do: doc

  defp persist_hostname(_doc, id, updates) when is_binary(id) do
    Couch.update_doc("studenten", id, updates)
  rescue
    _ -> :ok
  end

  defp persist_hostname(_doc, _id, _updates), do: :ok

  defp normalize_hostname(value) when is_binary(value) do
    value
    |> String.trim()
  end

  defp normalize_hostname(_), do: ""

  defp human_reason(:network_unknown, _user_session, metadata) do
    incoming = metadata |> Map.get(:ssid) |> to_string() |> String.trim()
    if incoming == "", do: "onbekende lokatie", else: "onbekende lokatie (#{incoming})"
  end

  defp human_reason(:no_stage_day, _user_session, _metadata), do: "geen stagedag"

  defp human_reason(:hostname_mismatch, user_session, metadata) do
    stored = user_session |> Map.get("hostname") |> to_string() |> String.trim()
    incoming = metadata |> Map.get(:hostname) |> to_string() |> String.trim()
    "onbekende laptop (verwacht: #{stored}, ontvangen: #{incoming})"
  end

  defp human_reason(_, _user_session, _metadata), do: "aanwezigheid niet opgeslagen"
end
