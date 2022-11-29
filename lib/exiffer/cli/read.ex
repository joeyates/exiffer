defmodule Exiffer.CLI.Read do
  @moduledoc """
  Documentation for `Exiffer.CLI.Read`.
  """

  require Logger

  @doc """
  Dump image file metadata.
  """
  def run(filename) do
    level = Logger.level()
    Logger.configure(level: :error)
    metadata = Exiffer.parse(filename)

    :ok = Exiffer.Serialize.puts(metadata)
    Logger.configure(level: level)

    {:ok}
  end
end
