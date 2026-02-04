defmodule Registratie.Logger.LoginFileBackend do
  @moduledoc """
  Logger backend that writes info-level login metadata to a dedicated file.

  It delegates all behaviour to `Registratie.Logger.ErrorFileBackend`; separate
  configuration (path/level/metadata/format) controls the output file.
  """
  @behaviour :gen_event

  defdelegate init(opts), to: Registratie.Logger.ErrorFileBackend
  defdelegate handle_call(msg, state), to: Registratie.Logger.ErrorFileBackend
  defdelegate handle_event(event, state), to: Registratie.Logger.ErrorFileBackend
  defdelegate code_change(old, state, extra), to: Registratie.Logger.ErrorFileBackend
  defdelegate terminate(reason, state), to: Registratie.Logger.ErrorFileBackend
end
