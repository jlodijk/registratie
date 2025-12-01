defmodule Registratie.CouchdbRoles do
  @moduledoc """
  Haalt rolgegevens op uit CouchDB met Req.
  """

  @config Application.compile_env(:registratie, :couchdb)

  def get_role(role_id) do
    url = "#{@config[:base_url]}/#{@config[:roles_db]}/#{role_id}"

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, "CouchDB gaf status #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
