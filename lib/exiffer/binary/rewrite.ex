defmodule Exiffer.Binary.Rewrite do
  @moduledoc """
  Rewrite an image file in memory
  """

  alias Exiffer.IO.Buffer
  alias Exiffer.{GPS, JPEG, Rewrite}

  def set_gps(source, %{longitude: longitude, latitude: latitude, altitude: altitude}) when is_binary(source) do
    input = Buffer.new_from_binary(source)
    {jpeg, input} = Exiffer.parse(input)

    gps = %GPS{longitude: longitude, latitude: latitude, altitude: altitude}

    headers = Rewrite.set_gps(jpeg, gps)
    header_binary = Exiffer.Serialize.binary(headers)
    remainder = input.size - input.position
    {rest, input} = Buffer.consume(input, remainder)
    :ok = Buffer.close(input)

    <<
      JPEG.magic()::binary,
      header_binary::binary,
      rest::binary
    >>
  end
end
