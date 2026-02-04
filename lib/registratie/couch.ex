defmodule Registratie.Couch do
  @moduledoc """
  CouchDB client met dubbele writes: primair (couchdb1) blokkerend, secundair (couchdb2) asynchroon.
  Lezen blijft van de primaire node.
  """

  require Logger

  # Publieke API (ongewijzigde signatures)

  # → Ophalen
  def get_doc(db, id) do
    req = client(db)
    Req.get!(req, url: "/#{id}").body
  end

  # → Aanmaken
  def create_doc(db, doc) do
    req = client(db)
    IO.inspect(doc, label: "CouchDB payload (#{db})")
    primary_resp = Req.post!(req, json: doc).body
    async_secondary(:create, db, doc)
    primary_resp
  end

  # → Overschrijven (volledige doc)
  def put_doc(db, id, doc) do
    req = client(db)
    primary_resp = Req.put!(req, url: "/#{id}", json: doc).body
    async_secondary(:put, db, {id, doc})
    primary_resp
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

  # → Updaten (merge)
  def update_doc(db, id, updates) when is_map(updates) do
    req = client(db)
    current = Req.get!(req, url: "/#{id}").body

    updated =
      current
      |> Map.merge(updates)
      |> Map.put("_id", id)
      |> Map.put("_rev", current["_rev"])

    primary_resp = Req.put!(req, url: "/#{id}", json: updated).body
    async_secondary(:update, db, {id, updates})
    primary_resp
  end

  # → Verwijderen
  def delete_doc(db, id) do
    req = client(db)
    current = Req.get!(req, url: "/#{id}").body
    primary_resp = Req.delete!(req, url: "/#{id}?rev=#{current["_rev"]}").body
    async_secondary(:delete, db, id)
    primary_resp
  end

  # -------------------------
  # Privé helpers
  # -------------------------

  defp client(db) do
    base_url = couchdb_url(db)
    {username, password} = couchdb_credentials()

    userinfo = "#{username}:#{password}"

    Req.new(
      base_url: base_url,
      auth: {:basic, userinfo},
      json: true
    )
  end

  defp secondary_client(db) do
    with {:ok, %{url: url, username: username, password: password}} <- secondary_config() do
      base_url = "#{String.trim_trailing(url, "/")}/#{db}"
      userinfo = "#{username}:#{password}"

      {:ok,
       Req.new(
         base_url: base_url,
         auth: {:basic, userinfo},
         json: true
       )}
    else
      :disabled -> :disabled
    end
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

  defp secondary_config do
    case Application.get_env(:registratie, :couchdb_secondary_url) do
      nil -> :disabled
      url when url != "" ->
        %{
          url: url,
          username: Application.get_env(:registratie, :couchdb_secondary_username),
          password: Application.get_env(:registratie, :couchdb_secondary_password)
        }
        |> then(fn
          %{username: nil} -> :disabled
          %{password: nil} -> :disabled
          cfg -> {:ok, cfg}
        end)
    end
  end

  defp async_secondary(action, db, payload) do
    if secondary_available?() do
      Task.Supervisor.start_child(Registratie.Couch.TaskSup, fn ->
        do_secondary_write(action, db, payload)
      end)
    else
      :ok
    end
  end

  defp do_secondary_write(:create, db, doc), do: secondary_post(db, doc)
  defp do_secondary_write(:put, db, {id, doc}), do: secondary_put(db, id, doc)
  defp do_secondary_write(:update, db, {id, updates}), do: secondary_update(db, id, updates)
  defp do_secondary_write(:delete, db, id), do: secondary_delete(db, id)

  defp secondary_post(db, doc) do
    with {:ok, req} <- secondary_client(db) do
      Req.post!(req, json: doc)
    end
  rescue
    e -> log_secondary_failure(:create, db, e)
  end

  defp secondary_put(db, id, doc) do
    with {:ok, req} <- secondary_client(db) do
      # probeer met bestaande _rev van secundaire, anders create
      case Req.get(req, url: "/#{id}") do
        {:ok, %{status: 200, body: current}} ->
          merged =
            doc
            |> Map.put("_id", id)
            |> Map.put("_rev", current["_rev"])

          Req.put!(req, url: "/#{id}", json: merged)

        {:ok, %{status: 404}} ->
          Req.put!(req, url: "/#{id}", json: Map.put(doc, "_id", id))

        {:error, _} = err ->
          log_secondary_failure(:put, db, err)
      end
    end
  rescue
    e -> log_secondary_failure(:put, db, e)
  end

  defp secondary_update(db, id, updates) do
    with {:ok, req} <- secondary_client(db),
         {:ok, %{status: 200, body: current}} <- Req.get(req, url: "/#{id}") do
      updated =
        current
        |> Map.merge(updates)
        |> Map.put("_id", id)
        |> Map.put("_rev", current["_rev"])

      Req.put!(req, url: "/#{id}", json: updated)
    else
      {:ok, %{status: 404}} -> :noop
      {:error, _} = err -> log_secondary_failure(:update, db, err)
    end
  rescue
    e -> log_secondary_failure(:update, db, e)
  end

  defp secondary_delete(db, id) do
    with {:ok, req} <- secondary_client(db),
         {:ok, %{status: 200, body: current}} <- Req.get(req, url: "/#{id}") do
      Req.delete!(req, url: "/#{id}?rev=#{current["_rev"]}")
    else
      {:ok, %{status: 404}} -> :noop
      {:error, _} = err -> log_secondary_failure(:delete, db, err)
    end
  rescue
    e -> log_secondary_failure(:delete, db, e)
  end

  defp log_secondary_failure(action, db, error) do
    Logger.warning("Couch secondary #{action} failed for #{db}: #{inspect(error)}")
  end

  defp secondary_available? do
    match?({:ok, _}, secondary_config())
  end
end
