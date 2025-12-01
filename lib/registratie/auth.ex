defmodule Registratie.Auth do
  @moduledoc """
  Handles CouchDB authentication
  """

  def authenticate(username, password) do
    url = Application.fetch_env!(:registratie, :couchdb_url)

    IO.inspect(url, label: "CouchDB URL")
    IO.inspect(username, label: "Username")
    IO.inspect(password, label: "Password")

    full_url = url <> "/_session"
    # Req request
    response = Req.get!(full_url, auth: {:basic, "#{username}:#{password}"})

    case response do
      %Req.Response{status: 200, body: body} ->
        user_ctx = body["userCtx"]
        IO.inspect(user_ctx, label: "User Context")
        {:ok, user_ctx}

      %Req.Response{status: 401} ->
        {:error, :invalid_credentials}

      %Req.Response{status: status} ->
        {:error, {:unexpected_status, status}}
    end
  end

  def register(username, password) do
    url = Application.fetch_env!(:registratie, :couchdb_url)
    full_url = url <> "/_users"

    body =
      %{
        "_id" => "org.couchdb.user:#{username}",
        "name" => username,
        "roles" => [],
        "type" => "user",
        "password" => password
      }
      |> Jason.encode!()

    # Correcte Req.post/2 syntax
    case Req.post(full_url, body: body, headers: [{"Content-Type", "application/json"}]) do
      {:ok, %Req.Response{status: 201}} ->
        {:ok, %{username: username}}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "CouchDB returned #{status}: #{body}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
