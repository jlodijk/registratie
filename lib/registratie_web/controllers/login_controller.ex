defmodule RegistratieWeb.LoginController do
  use RegistratieWeb, :controller
  alias Registratie.{Attendance, Auth, Couch}

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

    case Auth.authenticate(username, password) do
      {:ok, user_ctx} ->
        first_password? = first_password_required?(username)
        user_session =
          user_ctx
          |> Map.merge(load_student_profile(user_ctx))
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
      hostname: get_session(conn, :client_hostname),
      bssid: get_session(conn, :client_bssid),
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
    |> maybe_put_metadata(:client_bssid, params["bssid"])
  end

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
    Attendance.log_login(user_session, metadata)
    conn
  end

  defp log_attendance(conn, :logout, user_session, metadata) do
    Attendance.log_logout(user_session, metadata)
    conn
  end

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

  defp load_student_profile(%{"name" => name}) do
    Couch.get_doc("studenten", name)
  rescue
    _ -> %{}
  end

  defp load_student_profile(_), do: %{}
end
