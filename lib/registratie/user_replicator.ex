defmodule Registratie.UserReplicator do
  @moduledoc """
  Synchroniseert de `_users` database tussen couchdb1 (primair) en couchdb2 (secundair) éénmalig bij start.
  """

  require Logger

  @interval_ms 6 * 60 * 60 * 1000  # elke 6 uur

  # Provide an explicit child spec so this module can be supervised directly.
  def child_spec(arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [arg]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link(_arg) do
    Task.start_link(fn ->
      replicate_once()
      schedule_next()
      loop()
    end)
  end

  defp loop do
    receive do
      :replicate ->
        replicate_once()
        schedule_next()
        loop()
    end
  end

  defp schedule_next do
    Process.send_after(self(), :replicate, @interval_ms)
  end

  defp replicate_once do
    with {:ok, primary} <- primary_cfg(),
         {:ok, secondary} <- secondary_cfg() do
      replicate(primary, secondary)
      replicate(secondary, primary)
    else
      {:error, msg} -> Logger.debug("UserReplicator skipped: " <> msg)
    end
  end

  defp replicate(%{base: src, auth: src_auth}, %{base: tgt, auth: tgt_auth}) do
    body = %{
      "source" => "#{with_auth(src, src_auth)}/_users",
      "target" => "#{with_auth(tgt, tgt_auth)}/_users",
      "create_target" => true
    }

    Logger.debug("Replicating _users #{src} -> #{tgt}")

    replicator_url = "#{with_auth(src, src_auth)}/_replicate"

    # POST to CouchDB's replication endpoint
    case Req.post(replicator_url, json: body) do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: status, body: resp}} ->
        Logger.warning("_users replication #{src} -> #{tgt} status #{status}: #{inspect(resp)}")

      {:error, exception} ->
        Logger.warning("_users replication #{src} -> #{tgt} failed: #{Exception.message(exception)}")
    end
  end

  defp primary_cfg do
    url = Application.get_env(:registratie, :couchdb_url)
    user = Application.get_env(:registratie, :couchdb_username)
    pass = Application.get_env(:registratie, :couchdb_password)

    build_cfg(url, user, pass, "primary")
  end

  defp secondary_cfg do
    url = Application.get_env(:registratie, :couchdb_secondary_url)
    user = Application.get_env(:registratie, :couchdb_secondary_username)
    pass = Application.get_env(:registratie, :couchdb_secondary_password)

    case url do
      nil -> {:error, "no secondary url"}
      "" -> {:error, "secondary url empty"}
      _ -> build_cfg(url, user, pass, "secondary")
    end
  end

  defp build_cfg(url, user, pass, label) do
    cond do
      is_nil(url) or url == "" -> {:error, "#{label} url missing"}
      is_nil(user) or is_nil(pass) -> {:error, "#{label} auth missing"}
      true ->
        trimmed = String.trim_trailing(url, "/")
        {:ok,
         %{
           base: trimmed,
           auth: "#{user}:#{pass}"
         }}
    end
  end

  defp with_auth(url, auth) do
    uri =
      url
      |> URI.parse()
      |> Map.put(:userinfo, auth)

    URI.to_string(uri)
  end
end
