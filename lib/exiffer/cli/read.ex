defmodule Exiffer.CLI.Read do
  @moduledoc """
  Documentation for `Exiffer.CLI.Read`.
  """

  require Logger

  @spec run(map) :: {:ok}
  @doc """
  Dump image file metadata.
  """
  def run(opts) do
    filename = Map.fetch!(opts, :filename)
    metadata = Exiffer.parse(filename)

    :ok = Exiffer.Serialize.puts(metadata)

    {:ok}
  end
end
