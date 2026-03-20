defmodule Exiffer.JPEG.Header.APP1 do
  @moduledoc """
  Documentation for `Exiffer.JPEG.Header.APP1`.
  """

  import Exiffer.Logging, only: [integer: 1]

  alias __MODULE__.{EXIF, XMP, XMPExtension}

  require Logger

  @exif_header "Exif\0\0"
  @adobe_xmp_header "http://ns.adobe.com/xap/1.0/\0"
  @adobe_extended_xmp_header "http://ns.adobe.com/xmp/extension/\0"

  def new(%{data: <<0xFF, 0xE1, _rest::binary>>} = buffer) do
    buffer = Exiffer.Buffer.skip(buffer, 2)

    case buffer.data do
      <<_length_bytes::binary-size(2), @exif_header::binary, _rest::binary>> ->
        Logger.debug("APP1 - found EXIF header")
        EXIF.new(buffer)

      <<_length_bytes::binary-size(2), @adobe_xmp_header::binary, _rest::binary>> ->
        XMP.new(buffer)

      <<_length_bytes::binary-size(2), @adobe_extended_xmp_header::binary, _rest::binary>> ->
        XMPExtension.new(buffer)

      _ ->
        chunk = Exiffer.Buffer.random(buffer, buffer.position + 2, 32)

        {:error,
         "Unknown APP1 segment at #{integer(buffer.position)}. Header: #{inspect(chunk, hex: true)}"}
    end
  end
end
