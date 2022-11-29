defmodule Exiffer.CLI.Rewrite do
  @moduledoc """
  Documentation for `Exiffer.CLI.Rewrite`.
  """

  alias Exiffer.Buffer
  require Logger

  @jpeg_magic <<0xff, 0xd8>>

  @doc """
  Rewrite an image's metadata.
  """
  def run(source, destination) do
    input = Buffer.new(source)
    output = Buffer.new(destination, direction: :write)

    {metadata, input} = Exiffer.parse(input)

    Buffer.write(output, @jpeg_magic)
    :ok = Exiffer.Serialize.write(metadata, output.io_device)

    Buffer.copy(input, output)

    :ok = Buffer.close(input)
    :ok = Buffer.close(output)

    {:ok}
  end
end
