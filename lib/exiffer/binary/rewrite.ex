defmodule Exiffer.Binary.Rewrite do
  @moduledoc """
  Rewrite an image file in memory
  """

  alias Exiffer.{GPS, JPEG}

  def rewrite(source, rewrite_fun) when is_function(rewrite_fun, 1) do
    header_binary =
      source
      |> Exiffer.parse_binary()
      |> rewrite_fun.()
      |> Exiffer.Serialize.binary()

    <<JPEG.magic()::binary, header_binary::binary>>
  end

  def set_field(source, field, value) do
    rewrite(source, &JPEG.set_field(&1, field, value))
  end

  def set_date_time(source, %NaiveDateTime{} = date_time) do
    rewrite(source, &JPEG.set_date_time(&1, date_time))
  end

  def set_gps(source, %{longitude: longitude, latitude: latitude, altitude: altitude})
      when is_binary(source) do
    gps = %GPS{
      latitude: latitude,
      longitude: longitude,
      altitude: altitude
    }

    rewrite(source, &JPEG.set_gps(&1, gps))
  end
end
