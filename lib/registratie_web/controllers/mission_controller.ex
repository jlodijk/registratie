defmodule RegistratieWeb.MissionController do
  use RegistratieWeb, :controller

  import Phoenix.Component, only: [to_form: 2]

  alias Registratie.Mission

  plug RegistratieWeb.Plugs.RequireAuthenticatedUser
  plug RegistratieWeb.Plugs.AuthorizeRole, "begeleider" when action in [:overview]

  def index(conn, _params) do
    user = conn.assigns[:current_user] || %{}
    student_name = user_name(user)

    cond do
      teacher?(user) ->
        redirect(conn, to: ~p"/missie/overzicht")

      student?(user) and student_name != "" ->
        {:ok, existing} = Mission.fetch(student_name, rescue?: true)

        render(conn, :index,
          page_title: "Missie",
          form: to_form(Mission.form_data(existing), as: :mission),
          sections: Mission.sections(),
          existing: existing,
          student_name: student_name
        )

      student?(user) ->
        conn
        |> put_flash(:error, "We konden je gebruikersnaam niet vinden. Log opnieuw in en probeer het nogmaals.")
        |> redirect(to: ~p"/home")

      true ->
        conn
        |> put_flash(:error, "Deze pagina is alleen beschikbaar voor studenten of docenten.")
        |> redirect(to: ~p"/home")
    end
  end

  def create(conn, %{"mission" => params}) do
    user = conn.assigns[:current_user] || %{}

    if student?(user) do
      case Mission.submit(params, user) do
        {:ok, _doc} ->
          conn
          |> put_flash(:info, "Missie opgeslagen.")
          |> redirect(to: ~p"/missie")

        {:error, message} ->
          conn
          |> put_flash(:error, message)
          |> redirect(to: ~p"/missie")
      end
    else
      conn
      |> put_flash(:error, "Alleen studenten kunnen dit formulier invullen.")
      |> redirect(to: ~p"/missie")
    end
  end

  def overview(conn, params) do
    submissions = Mission.list_all()
    selected_param = params["student"] |> to_string() |> String.trim()

    selected_submission =
      cond do
        selected_param != "" ->
          Enum.find(submissions, &(&1["student_name"] == selected_param)) ||
            case Mission.fetch(selected_param, rescue?: true) do
              {:ok, doc} -> doc
              _ -> nil
            end

        true ->
          List.first(submissions)
      end

    render(conn, :overview,
      page_title: "Missies",
      submissions: submissions,
      selected_submission: selected_submission,
      selected_student: selected_param,
      sections: Mission.sections()
    )
  end

  defp student?(user) do
    roles = Map.get(user, "roles") || Map.get(user, :roles) || []
    "studenten" in roles
  end

  defp teacher?(user) do
    roles = Map.get(user, "roles") || Map.get(user, :roles) || []
    Enum.any?(roles, &(&1 in ["begeleider", "admin"]))
  end

  defp user_name(user) do
    Map.get(user, "name") || Map.get(user, :name) || ""
  end
end
