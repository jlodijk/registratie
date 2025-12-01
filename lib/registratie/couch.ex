defmodule Registratie.Couch do
  @moduledoc """
  Eenvoudige CouchDB client met Req die zijn configuratie uit de applicatie haalt.
  """

  def client(db) do
    base_url = couchdb_url(db)
    {username, password} = couchdb_credentials()

    userinfo = "#{username}:#{password}"

    Req.new(
      base_url: base_url,
      auth: {:basic, userinfo},
      json: true
    )
  end

  defp couchdb_url(db) do
    url = Application.fetch_env!(:registratie, :couchdb_url)
    trimmed = String.trim_trailing(url, "/")
    "#{trimmed}/#{db}"
  end

  defp couchdb_credentials do
    {
      Application.fetch_env!(:registratie, :couchdb_username),
      Application.fetch_env!(:registratie, :couchdb_password)
    }
  end

  # → Ophalen
  def get_doc(db, id) do
    req = client(db)
    Req.get!(req, url: "/#{id}").body
  end

  # → Aanmaken
  def create_doc(db, doc) do
    req = client(db)
    IO.inspect(doc, label: "CouchDB payload (#{db})")
    Req.post!(req, json: doc).body
  end

  # → Overschrijven
  def put_doc(db, id, doc) do
    req = client(db)
    Req.put!(req, url: "/#{id}", json: doc).body
  end

  # → Alles ophalen
  def list_docs(db) do
    req = client(db)
    Req.get!(req, url: "/_all_docs", params: [include_docs: true]).body
  end

  def list_docs_range(db, start_key, end_key) do
    req = client(db)

    params = [
      include_docs: true,
      startkey: Jason.encode!(start_key),
      endkey: Jason.encode!(end_key)
    ]

    Req.get!(req, url: "/_all_docs", params: params).body
  end

  # → Zoeken met selector (_find)
  def find_docs(db, selector, opts \\ []) when is_map(selector) do
    req = client(db)
    body =
      opts
      |> Enum.into(%{})
      |> Map.put(:selector, selector)

    Req.post!(req, url: "/_find", json: body).body
  end

  # → Updaten
  def update_doc(db, id, updates) when is_map(updates) do
    req = client(db)
    current = Req.get!(req, url: "/#{id}").body

    updated =
      current
      |> Map.merge(updates)
      |> Map.put("_id", id)
      |> Map.put("_rev", current["_rev"])

    Req.put!(req, url: "/#{id}", json: updated).body
  end

  # → Verwijderen
  def delete_doc(db, id) do
    req = client(db)
    current = Req.get!(req, url: "/#{id}").body
    Req.delete!(req, url: "/#{id}?rev=#{current["_rev"]}").body
  end
end
