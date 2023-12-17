defmodule Exiffer.JPEG.Header.APP1 do
  @moduledoc """
  Documentation for `Exiffer.JPEG.Header.APP1`.
  """

  require Logger

  alias Exiffer.JPEG.Header.APP1.{EXIF, XMP, XMPExtension}

  @exif_header "Exif\0\0"
  @adobe_xmp_header "http://ns.adobe.com/xap/1.0/\0"
  @adobe_extended_xmp_header "http://ns.adobe.com/xmp/extension/\0"

  def new(%{data: <<0xff, 0xe1, _rest::binary>>} = buffer) do
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
        raise "Unknown APP1 segment at #{Integer.to_string(buffer.position, 16)}. Header: #{inspect(chunk, hex: true)}"
    end
  end
end
