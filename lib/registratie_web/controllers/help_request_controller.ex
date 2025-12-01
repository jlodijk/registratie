defmodule RegistratieWeb.HelpRequestController do
  use RegistratieWeb, :controller

  import Phoenix.Component, only: [to_form: 2]

  alias Registratie.HelpRequest

  plug RegistratieWeb.Plugs.RequireAuthenticatedUser
  plug RegistratieWeb.Plugs.AuthorizeRole, "begeleider" when action in [:overview]
  plug :ensure_student when action in [:index, :create, :update_status]
  plug :ensure_teacher when action in [:feedback]

  def index(conn, params) do
    user = conn.assigns[:current_user] || %{}
    student_name = user_name(user)
    status_filter = normalize_status(Map.get(params, "status", "open"))

    requests = HelpRequest.list_for_student(student_name, status: status_filter)

    render(conn, :index,
      page_title: "Hulpvragen",
      form: to_form(default_form_data(), as: :help_request),
      requests: requests,
      status_filter: status_filter,
      statuses: statuses(),
      categories: categories(),
      student_name: student_name
    )
  end

  def create(conn, %{"help_request" => params}) do
    case HelpRequest.submit(params, conn.assigns[:current_user]) do
      {:ok, _doc} ->
        conn
        |> put_flash(:info, "Hulpvraag opgeslagen.")
        |> redirect(to: ~p"/hulpvragen")

      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/hulpvragen")
    end
  end

  def update_status(conn, %{"id" => id, "status" => status}) do
    case HelpRequest.update_status(id, status, conn.assigns[:current_user]) do
      {:ok, _doc} ->
        conn
        |> put_flash(:info, "Status bijgewerkt.")
        |> redirect(to: ~p"/hulpvragen")

      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/hulpvragen")
    end
  end

  def overview(conn, params) do
    status_filter = normalize_status(Map.get(params, "status", ""))
    requests = HelpRequest.list_all(status: status_filter)

    render(conn, :overview,
      page_title: "Hulpvragen overzicht",
      requests: requests,
      status_filter: status_filter,
      statuses: statuses(),
      categories: categories(),
      feedback_categories: feedback_categories()
    )
  end

  def feedback(conn, %{"id" => id, "help_request" => params}) do
    case HelpRequest.add_feedback(id, params, conn.assigns[:current_user]) do
      {:ok, _doc} ->
        conn
        |> put_flash(:info, "Commentaar opgeslagen.")
        |> redirect(to: ~p"/hulpvragen/overzicht")

      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/hulpvragen/overzicht")
    end
  end

  defp ensure_student(conn, _opts) do
    roles = roles(conn.assigns[:current_user])

    if "studenten" in roles do
      conn
    else
      conn
      |> put_flash(:error, "Alleen studenten kunnen hulpvragen registreren.")
      |> redirect(to: ~p"/home")
      |> halt()
    end
  end

  defp roles(%{} = user) do
    Map.get(user, "roles") || Map.get(user, :roles) || []
  end

  defp roles(_), do: []

  defp ensure_teacher(conn, _opts) do
    if "begeleider" in roles(conn.assigns[:current_user]) or "admin" in roles(conn.assigns[:current_user]) do
      conn
    else
      conn
      |> put_flash(:error, "Alleen begeleiders kunnen commentaar toevoegen.")
      |> redirect(to: ~p"/home")
      |> halt()
    end
  end

  defp user_name(user) do
    Map.get(user, "name") || Map.get(user, :name) || ""
  end

  defp statuses, do: ["open", "afgerond"]
  defp categories, do: ["Mobiel", "Tablet", "Laptop", "Internet/Wifi", "Account", "Overig"]
  defp feedback_categories, do: ["Goed", "Voldoende", "Onvoldoende", "Opnieuw", "Let op"]

  defp normalize_status(nil), do: nil
  defp normalize_status(""), do: nil
  defp normalize_status(status), do: status

  defp default_form_data do
    %{
      customer_first_name: "",
      category: "Overig",
      device_type: "",
      question: "",
      solution: "",
      escalated: "nee",
      followup_when: "",
      followup_notes: "",
      status: "open"
    }
  end
end
