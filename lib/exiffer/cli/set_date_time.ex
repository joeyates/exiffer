defmodule Exiffer.CLI.SetDateTime do
  @moduledoc """
  Documentation for `Exiffer.CLI.SetDateTime`.
  """

  alias Exiffer.{Binary, JPEG, Rewrite}
  alias Exiffer.IO.Buffer
  require Logger

  @spec run(map) :: {:ok}
  @doc """
  Rewrite an image's creation metadata.
  """
  def run(opts) do
    Logger.info "Exiffer.CLI.SetDateTime.run/4"
    source = Map.fetch!(opts, :source)
    destination = Map.fetch!(opts, :destination)
    year = Map.fetch!(opts, :year)
    month = Map.get(opts, :month, 1)
    day = Map.get(opts, :day, 1)
    hour = Map.get(opts, :hour, 0)
    minute = Map.get(opts, :minute, 0)
    second = Map.get(opts, :second, 0)

    date_time = NaiveDateTime.new!(year, month, day, hour, minute, second)
    input = Buffer.new(source)

    {:ok, metadata, input} = Rewrite.set_date_time(input, date_time)

    Logger.debug "Setting initial byte order to :big"
    Binary.set_byte_order(:big)

    output = Buffer.new(destination, direction: :write)
    Buffer.write(output, JPEG.magic())
    :ok = Exiffer.Serialize.write(metadata, output.io_device)

    Buffer.copy(input, output)

    :ok = Buffer.close(input)
    :ok = Buffer.close(output)

    {:ok}
  end
end
