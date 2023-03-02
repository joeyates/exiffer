defmodule Exiffer.Binary.Rewrite do
  @moduledoc """
  Rewrite an image file, adding and removing arbitrary metadata
  """

  alias Exiffer.Binary.Buffer
  alias Exiffer.{GPS, JPEG, Rewrite}

  def set_gps(source, %{longitude: longitude, latitude: latitude, altitude: altitude}) when is_binary(source) do
    input = Buffer.new(source)

    gps = %GPS{longitude: longitude, latitude: latitude, altitude: altitude}

    {:ok, metadata, input} = Rewrite.set_gps(input, gps)

    header_binary = Exiffer.Serialize.binary(metadata)
    remainder = input.size - input.position
    <<_before::binary-size(input.position), rest::binary-size(remainder)>> = input.original

    <<
      JPEG.magic()::binary(),
      header_binary::binary(),
      rest::binary()
    >>
  end
end
