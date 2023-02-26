defmodule Exiffer.Header.APP1.XMP do
  @moduledoc """
  Documentation for `Exiffer.Header.APP1.XMP`.
  """

  alias Exiffer.{Binary, Buffer}

  @adobe_xmp_header "http://ns.adobe.com/xap/1.0/\0"

  @enforce_keys ~w(xpacket)a
  defstruct ~w(xpacket)a

  def new(%{data: <<length_bytes::binary-size(2), @adobe_xmp_header::binary, _rest::binary>>} = buffer) do
    length = Binary.big_endian_to_integer(length_bytes)
    header_length = String.length(@adobe_xmp_header)
    buffer = Buffer.skip(buffer, 2 + header_length)
    xpacket_length = length - 2 - header_length
    {xpacket, buffer} = Buffer.consume(buffer, xpacket_length)
    xmp = %__MODULE__{xpacket: xpacket}
    {xmp, buffer}
  end

  def puts(%__MODULE__{} = xmp) do
    truncated = if String.length(xmp.xpacket) > 47 do
      "#{String.slice(xmp.xpacket, 0, 47)}..."
    else
      xmp.xpacket
    end
    IO.puts "XPacket"
    IO.puts "-------"
    IO.puts truncated
    :ok
  end

  defimpl Exiffer.Serialize do
    def write(xmp, io_device) do
      Exiffer.Header.APP1.XMP.write(xmp, io_device)
    end

    def binary(_xmp) do
      <<>>
    end

    def puts(xmp) do
      Exiffer.Header.APP1.XMP.puts(xmp)
    end
  end
end
