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
    format = Map.get(opts, :format, "text")
    metadata = Exiffer.parse(filename)

    case format do
      "text" ->
        :ok = Exiffer.Serialize.puts(metadata)

      "json" ->
        IO.puts(Jason.encode!(metadata))

      _ ->
        IO.puts("Unknown format: #{format}")
    end

    {:ok}
  end
end
