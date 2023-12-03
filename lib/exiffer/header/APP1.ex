defmodule Exiffer.Header.APP1 do
  @moduledoc """
  Documentation for `Exiffer.Header.APP1`.
  """

  require Logger

  alias Exiffer.Buffer
  alias Exiffer.Header.APP1.{EXIF, XMP}

  @exif_header "Exif\0\0"
  @adobe_xmp_header "http://ns.adobe.com/xap/1.0/\0"

  def new(%{data: <<0xff, 0xe1, _rest::binary>>} = buffer) do
    buffer = Buffer.skip(buffer, 2)
    cond do
      Buffer.random(buffer, buffer.position + 2, String.length(@exif_header)) == @exif_header ->
        Logger.debug("APP1 - found EXIF header")
        EXIF.new(buffer)
      Buffer.random(buffer, buffer.position + 2, String.length(@adobe_xmp_header)) == @adobe_xmp_header ->
        XMP.new(buffer)
      true ->
        raise "Unknown APP1 segment at #{Integer.to_string(buffer.position, 16)}"
    end
  end
end
