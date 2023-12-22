defmodule Exiffer.JPEG.Header.APP1.XMP do
  @moduledoc """
  Documentation for `Exiffer.JPEG.Header.APP1.XMP`.
  """

  alias Exiffer.Binary
  require Logger

  @adobe_xmp_header "http://ns.adobe.com/xap/1.0/\0"

  @enforce_keys ~w(xpacket)a
  defstruct ~w(xpacket)a

  defimpl Jason.Encoder  do
    @spec encode(%Exiffer.JPEG.Header.APP1.XMP{}, Jason.Encode.opts()) :: String.t()
    def encode(entry, opts) do
      Jason.Encode.map(
        %{
          module: "Exiffer.JPEG.Header.APP1.XMP",
          xpacket: "(#{byte_size(entry.xpacket)} bytes)",
        },
        opts
      )
    end
  end

  def new(%{data: <<length_bytes::binary-size(2), @adobe_xmp_header::binary, _rest::binary>>} = buffer) do
    length = Binary.big_endian_to_integer(length_bytes)
    header_length = String.length(@adobe_xmp_header)
    buffer = Exiffer.Buffer.skip(buffer, 2 + header_length)
    xpacket_length = length - 2 - header_length
    {xpacket, buffer} = Exiffer.Buffer.consume(buffer, xpacket_length)
    xmp = %__MODULE__{xpacket: xpacket}
    {:ok, xmp, buffer}
  end

  def text(%__MODULE__{} = xmp) do
    """
    XMP
    ---
    #{byte_size(xmp.xpacket)} bytes
    """
  end

  def binary(%__MODULE__{xpacket: xpacket}), do: xpacket

  def write(%__MODULE__{} = data, io_device) do
    Logger.debug "Writing APP1.XMP header"
    binary = binary(data)
    :ok = IO.binwrite(io_device, binary)
  end

  defimpl Exiffer.Serialize do
    alias Exiffer.JPEG.Header.APP1.XMP

    def binary(xmp) do
      XMP.binary(xmp)
    end

    def text(xmp) do
      XMP.text(xmp)
    end

    def write(xmp, io_device) do
      XMP.write(xmp, io_device)
    end
  end
end
