defmodule RegistratieWeb.StandardTaskController do
  use RegistratieWeb, :controller

  import Phoenix.Component, only: [to_form: 2]

  alias Registratie.StandardTasks

  plug RegistratieWeb.Plugs.RequireAuthenticatedUser
  plug RegistratieWeb.Plugs.AuthorizeRole, "begeleider"

  def index(conn, _params) do
    render(conn, :index,
      page_title: "Standaard taken",
      tasks: StandardTasks.list(),
      form: to_form(%{}, as: :standard_task)
    )
  end

  def create(conn, %{"standard_task" => %{"taak" => taak}}) do
    case StandardTasks.add(taak) do
      {:ok, _tasks} ->
        conn
        |> put_flash(:info, "Taak toegevoegd aan de standaardlijst.")
        |> redirect(to: ~p"/standaard-taken")

      {:error, reason} ->
        conn
        |> put_flash(:error, reason)
        |> redirect(to: ~p"/standaard-taken")
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Ongeldig formulier.")
    |> redirect(to: ~p"/standaard-taken")
  end

  def delete(conn, %{"task" => taak}) do
    case StandardTasks.remove(taak) do
      {:ok, _tasks} ->
        conn
        |> put_flash(:info, "Taak verwijderd uit de standaardlijst.")
        |> redirect(to: ~p"/standaard-taken")

      {:error, reason} ->
        conn
        |> put_flash(:error, reason)
        |> redirect(to: ~p"/standaard-taken")
    end
  end
end
