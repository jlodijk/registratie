defmodule RegistratieWeb.PasswordController do
  use RegistratieWeb, :controller

  import Phoenix.Component, only: [to_form: 2]

  alias Registratie.Couch

  plug RegistratieWeb.Plugs.RequireAuthenticatedUser
  plug :ensure_first_password when action in [:new, :create]
  plug :ensure_reset_privileges when action in [:reset_form, :reset]

  @requirements [
    "Minimaal 8 tekens lang",
    "Bevat ten minste één letter",
    "Bevat ten minste één cijfer"
  ]
  @users_db "_users"

  def new(conn, _params) do
    form = to_form(%{}, as: :password)

    render(conn, :new,
      page_title: "Nieuw wachtwoord instellen",
      requirements: @requirements,
      form: form
    )
  end

  def create(conn, %{"password" => params}) do
    user = conn.assigns[:current_user]
    new_password = Map.get(params, "new_password", "")
    confirm_password = Map.get(params, "confirm_password", "")

    cond do
      new_password == "" or confirm_password == "" ->
        render_error(conn, "Vul beide wachtwoordvelden in.", params)

      new_password != confirm_password ->
        render_error(conn, "Wachtwoorden komen niet overeen.", params)

      not valid_password?(new_password) ->
        render_error(
          conn,
          "Wachtwoord voldoet niet aan de eisen (minimaal 8 tekens, inclusief letters en cijfers).",
          params
        )

      true ->
        case update_couchdb_password(user["name"], new_password) do
          :ok ->
            updated_user = Map.put(user, "firstPassword", false)

            conn
            |> put_session(:current_user, updated_user)
            |> put_flash(:info, "Wachtwoord ingesteld. Je kunt nu verder.")
            |> redirect(to: ~p"/home")

          {:error, message} ->
            render_error(conn, "Wachtwoord opslaan mislukt: #{message}", params)
        end
    end
  end

  def reset_form(conn, _params) do
    form = to_form(%{}, as: :reset)

    render(conn, :reset,
      page_title: "Wachtwoord resetten",
      requirements: @requirements,
      form: form
    )
  end

  def reset(conn, %{"reset" => params}) do
    username =
      params
      |> Map.get("username", "")
      |> to_string()
      |> String.trim()

    clean_params = Map.put(params, "username", username)
    new_password = Map.get(params, "new_password", "")
    confirm_password = Map.get(params, "confirm_password", "")

    case validate_reset_params(username, new_password, confirm_password) do
      {:error, message} ->
        render_reset_error(conn, message, clean_params)

      :ok ->
        with {:ok, target_doc} <- fetch_user_doc(username),
             :ok <- authorize_reset(conn.assigns[:current_user], target_doc),
             :ok <- update_couchdb_password(username, new_password, first_password: true) do
          conn
          |> put_flash(:info, "Wachtwoord voor #{username} is opnieuw ingesteld.")
          |> redirect(to: ~p"/home")
        else
          {:error, message} ->
            render_reset_error(conn, message, clean_params)
        end
    end
  end

  defp render_error(conn, message, params) do
    form = to_form(params, as: :password)

    conn
    |> put_flash(:error, message)
    |> render(:new,
      page_title: "Nieuw wachtwoord instellen",
      requirements: @requirements,
      form: form
    )
  end

  defp render_reset_error(conn, message, params) do
    form = to_form(params, as: :reset)

    conn
    |> put_flash(:error, message)
    |> render(:reset, page_title: "Wachtwoord resetten", requirements: @requirements, form: form)
  end

  defp valid_password?(password) when is_binary(password) do
    String.length(password) >= 8 and
      String.match?(password, ~r/[A-Za-z]/) and
      String.match?(password, ~r/\d/)
  end

  defp valid_password?(_), do: false

  defp update_couchdb_password(name, new_password, opts \\ []) do
    updates = %{
      "password" => new_password,
      "firstPassword" => Keyword.get(opts, :first_password, false)
    }

    case Couch.update_doc(@users_db, "org.couchdb.user:#{name}", updates) do
      %{"ok" => true} -> :ok
      %{"error" => error, "reason" => reason} -> {:error, "#{error}: #{reason}"}
      other -> {:error, "Onbekend antwoord: #{inspect(other)}"}
    end
  rescue
    exception -> {:error, Exception.message(exception)}
  end

  defp fetch_user_doc(username) do
    {:ok, Couch.get_doc(@users_db, "org.couchdb.user:#{username}")}
  rescue
    _ -> {:error, "Gebruiker #{username} is niet gevonden."}
  end

  defp authorize_reset(actor, target_doc) do
    actor_roles = user_roles(actor)
    target_roles = Map.get(target_doc, "roles", [])

    cond do
      "admin" in actor_roles ->
        :ok

      "begeleider" in actor_roles and "studenten" in target_roles ->
        :ok

      true ->
        {:error, "Je mag alleen wachtwoorden voor studenten resetten."}
    end
  end

  defp validate_reset_params(username, new_password, confirm_password) do
    cond do
      username == "" ->
        {:error, "Vul een gebruikersnaam in."}

      new_password == "" or confirm_password == "" ->
        {:error, "Vul beide wachtwoordvelden in."}

      new_password != confirm_password ->
        {:error, "Wachtwoorden komen niet overeen."}

      not valid_password?(new_password) ->
        {:error,
         "Wachtwoord voldoet niet aan de eisen (minimaal 8 tekens, inclusief letters en cijfers)."}

      true ->
        :ok
    end
  end

  defp ensure_first_password(conn, _opts) do
    user = conn.assigns[:current_user]

    if user && Map.get(user, "firstPassword", false) do
      conn
    else
      conn
      |> put_flash(:info, "Je wachtwoord is al ingesteld.")
      |> redirect(to: ~p"/home")
      |> halt()
    end
  end

  defp ensure_reset_privileges(conn, _opts) do
    if Enum.any?(user_roles(conn.assigns[:current_user]), &(&1 in ["begeleider", "admin"])) do
      conn
    else
      conn
      |> put_flash(:error, "Alleen begeleiders of admins kunnen wachtwoorden resetten.")
      |> redirect(to: ~p"/home")
      |> halt()
    end
  end

  defp user_roles(%{} = user) do
    cond do
      Map.has_key?(user, "roles") -> Map.get(user, "roles", [])
      Map.has_key?(user, :roles) -> Map.get(user, :roles, [])
      true -> []
    end
  end

  defp user_roles(_), do: []
end
