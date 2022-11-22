defmodule Exiffer.CLI.Read do
  @moduledoc """
  Documentation for `Exiffer.CLI.Read`.
  """

  require Logger

  @doc """
  Dump image file metadata.
  """
  def run(filename) do
    headers = Exiffer.parse(filename)

    IO.puts "headers: #{inspect(headers, [pretty: true, width: 0])}"

    {:ok}
  end
end
