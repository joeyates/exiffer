defmodule Exiffer.CLI.Rewrite do
  @moduledoc """
  Documentation for `Exiffer.CLI.Rewrite`.
  """

  alias Exiffer.{Binary, GPS, JPEG, Rewrite}
  alias Exiffer.IO.{Buffer}
  require Logger

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

    Logger.debug "Setting initial byte order to :big"
    Binary.set_byte_order(:big)

    output = Buffer.new(destination, direction: :write)
    Buffer.write(output, JPEG.magic())
    :ok = Exiffer.Serialize.write(metadata, output.io_device)

    Buffer.copy(input, output)

    :ok = Buffer.close(input)
    :ok = Buffer.close(output)

    Logger.configure(level: level)

    {:ok}
  end
end
