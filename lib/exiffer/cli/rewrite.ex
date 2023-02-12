defmodule Exiffer.CLI.Rewrite do
  @moduledoc """
  Documentation for `Exiffer.CLI.Rewrite`.
  """

  alias Exiffer.Buffer
  alias Exiffer.GPS
  alias Exiffer.Rewrite
  require Logger

  @jpeg_magic <<0xff, 0xd8>>

  @doc """
  Rewrite an image's metadata.
  """
  def run(source, destination, gps_text, opts \\ []) do
    logger_level = Keyword.get(opts, :log_level, :error)
    level = Logger.level()
    Logger.configure(level: logger_level)

    input = Buffer.new(source)

    %GPS{} = gps = GPS.parse(gps_text)

    {:ok, metadata, input} = Rewrite.set_gps(input, gps)

    output = Buffer.new(destination, direction: :write)
    Buffer.write(output, @jpeg_magic)
    :ok = Exiffer.Serialize.write(metadata, output.io_device)

    Buffer.copy(input, output)

    :ok = Buffer.close(input)
    :ok = Buffer.close(output)

    Logger.configure(level: level)

    {:ok}
  end
end
