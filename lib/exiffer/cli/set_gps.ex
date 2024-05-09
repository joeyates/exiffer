defmodule Exiffer.CLI.SetGPS do
  @moduledoc """
  Documentation for `Exiffer.CLI.SetGPS`.
  """

  require Logger

  alias Exiffer.{GPS, Rewrite}

  @spec run(map) :: {:ok}
  @doc """
  Rewrite an image's GPS metadata.
  """
  def run(opts) do
    Logger.info "Exiffer.CLI.SetGPS.run/4"
    source = Map.fetch!(opts, :source)
    destination = Map.fetch!(opts, :destination)
    latitude = Map.fetch!(opts, :latitude)
    longitude = Map.fetch!(opts, :longitude)
    altitude = Map.get(opts, :altitude, 0)

    gps = %GPS{latitude: latitude, longitude: longitude, altitude: altitude}

    :ok = Rewrite.set_gps(source, destination, gps)
  end
end
