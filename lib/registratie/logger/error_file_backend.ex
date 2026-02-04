defmodule Registratie.Logger.ErrorFileBackend do
  @moduledoc """
  Minimal Logger backend that writes error-level logs to a dedicated file.
  """
  @behaviour :gen_event

  require Logger

  defstruct [:io_device, :path, :level, :format, metadata: []]

  @impl true
  def init({__MODULE__, name}) do
    config = Application.get_env(:logger, {__MODULE__, name}, [])
    {:ok, configure_backend(config)}
  end

  def init({backend, name}) when is_atom(backend) do
    config = Application.get_env(:logger, {backend, name}, [])
    {:ok, configure_backend(config)}
  end

  def init(__MODULE__) do
    config = Application.get_env(:logger, __MODULE__, [])
    {:ok, configure_backend(config)}
  end

  def init(backend) when is_atom(backend) do
    config = Application.get_env(:logger, backend, [])
    {:ok, configure_backend(config)}
  end

  def init(config) when is_list(config) do
    {:ok, configure_backend(config)}
  end

  @impl true
  def handle_call({:configure, new_config}, state) do
    {:ok, :ok, configure_backend(state, new_config)}
  end

  def handle_call(_msg, state), do: {:ok, :ok, state}

  @impl true
  def handle_event(:flush, state) do
    {:ok, state}
  end

  def handle_event({level, _gl, {Logger, message, timestamp, metadata}}, state) do
    maybe_write(level, message, timestamp, metadata, state)
    {:ok, state}
  end

  def handle_event(_, state), do: {:ok, state}

  @impl true
  def code_change(_old_vsn, state, _extra), do: {:ok, state}

  @impl true
  def terminate(_reason, %{io_device: io}) when not is_nil(io) do
    File.close(io)
    :ok
  end

  def terminate(_reason, _state), do: :ok

  defp configure_backend(config) do
    path = Keyword.get(config, :path, default_path())
    level = Keyword.get(config, :level, :error)
    metadata = Keyword.get(config, :metadata, [])

    format =
      config
      |> Keyword.get(:format, default_format())
      |> Logger.Formatter.compile()

    io_device = open_file(path)

    %__MODULE__{
      path: path,
      level: level,
      metadata: metadata,
      format: format,
      io_device: io_device
    }
  end

  defp configure_backend(state, config) do
    new_path = Keyword.get(config, :path, state.path)
    metadata = Keyword.get(config, :metadata, state.metadata)
    level = Keyword.get(config, :level, state.level)

    format =
      if Keyword.has_key?(config, :format) do
        config
        |> Keyword.get(:format)
        |> Logger.Formatter.compile()
      else
        state.format
      end

    io_device =
      if new_path != state.path do
        File.close(state.io_device)
        open_file(new_path)
      else
        state.io_device
      end

    %{
      state
      | path: new_path,
        level: level,
        metadata: metadata,
        io_device: io_device,
        format: format
    }
  end

  defp maybe_write(level, message, timestamp, metadata, state) do
    if meets_level?(level, state.level) do
      metadata_subset = filter_metadata(metadata, state.metadata)

      formatted =
        Logger.Formatter.format(state.format, level, message, timestamp, metadata_subset)

      IO.binwrite(state.io_device, formatted)
    end
  end

  defp meets_level?(level, min_level) do
    Logger.compare_levels(level, min_level) != :lt
  end

  defp filter_metadata(metadata, []), do: metadata
  defp filter_metadata(metadata, keys), do: Keyword.take(metadata, keys)

  defp open_file(path) do
    path |> Path.dirname() |> File.mkdir_p!()
    {:ok, io} = File.open(path, [:append])
    io
  end

  defp default_path, do: Path.join(["log", "errors", "error.log"])
  defp default_format, do: "$date $time [$level] $message\n"
end
