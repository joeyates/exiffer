defmodule Exiffer.CLI.Read do
  @moduledoc """
  Documentation for `Exiffer.CLI.Read`.
  """

  require Logger

  @doc """
  Dump image file metadata.
  """
  def run(filename, opts \\ []) do
    logger_level = Keyword.get(opts, :log_level, :error)
    level = Logger.level()
    Logger.configure(level: logger_level)
    metadata = Exiffer.parse(filename)

    :ok = Exiffer.Serialize.puts(metadata)
    Logger.configure(level: level)

    {:ok}
  end
end
