defmodule Exiffer.CLI.Read do
  @moduledoc """
  Documentation for `Exiffer.CLI.Read`.
  """

  require Logger

  @doc """
  Dump image file metadata.
  """
  def run(filename) do
    metadata = Exiffer.parse(filename)

    IO.puts "metadata: #{inspect(metadata.headers, [pretty: true, width: 0])}"

    {:ok}
  end
end
