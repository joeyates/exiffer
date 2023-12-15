defmodule Exiffer.CLI.SetGPS do
  @moduledoc """
  Documentation for `Exiffer.CLI.SetGPS`.
  """

  alias Exiffer.{Binary, GPS, JPEG, Rewrite}
  alias Exiffer.IO.Buffer
  require Logger

  @spec run(map) :: {:ok}
  @doc """
  Rewrite an image's GPS metadata.
  """
  def run(opts) do
    Logger.info "Exiffer.CLI.Rewrite.run/4"
    source = Map.fetch!(opts, :source)
    destination = Map.fetch!(opts, :destination)
    latitude = Map.fetch!(opts, :latitude)
    longitude = Map.fetch!(opts, :longitude)
    altitude = Map.get(opts, :altitude, 0)

    gps = %GPS{latitude: latitude, longitude: longitude, altitude: altitude}
    input = Buffer.new(source)

    {:ok, metadata, input} = Rewrite.set_gps(input, gps)

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
