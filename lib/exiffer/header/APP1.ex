defmodule Exiffer.Header.APP1 do
  @moduledoc """
  Documentation for `Exiffer.Header.APP1`.
  """

  alias Exiffer.Binary
  alias Exiffer.Buffer
  alias Exiffer.IFDBlock
  require Logger

  @tiff_header_marker <<0x00, 0x2a>>
  @exif_header "Exif\0\0"

  @enforce_keys ~w(byte_order ifd_block)a
  defstruct ~w(byte_order ifd_block)a

  def new(%Buffer{data: <<0xff, 0xe1, _rest::binary>>} = buffer) do
    buffer = Buffer.skip(buffer, 2)
    app1_start = buffer.position
    {<<length_bytes::binary-size(2)>>, buffer} = Buffer.consume(buffer, 2)
    length = Binary.big_endian_to_integer(length_bytes)
    {@exif_header, buffer} = Buffer.consume(buffer, 6)
    {byte_order_marker, buffer} = Buffer.consume(buffer, 2)
    byte_order = if byte_order_marker == "MM", do: :big, else: :little
    Binary.set_byte_order(byte_order)
    tiff_header_marker = Binary.big_endian_to_current(@tiff_header_marker)
    {<<^tiff_header_marker::binary-size(2), ifd_header_offset_binary::binary-size(4)>>, buffer} = Buffer.consume(buffer, 6)
    ifd_header_offset = Binary.to_integer(ifd_header_offset_binary)
    offset = app1_start + ifd_header_offset
    {ifd_block, buffer} = IFDBlock.new(buffer, offset)
    app1 = %__MODULE__{byte_order: byte_order, ifd_block: ifd_block}
    app1_end = app1_start + length
    Logger.debug "APP1 read completed, seeking to #{Integer.to_string(app1_end, 16)}"
    buffer = Buffer.seek(buffer, app1_end)
    {app1, buffer}
  end

  def write(%__MODULE__{} = app1, io_device) do
    tiff_header_marker = Binary.big_endian_to_current(@tiff_header_marker)
    ifd_block = IFDBlock.binary(app1.ifd_block)
    byte_order = if app1.byte_order == :big, do: "MM", else: "II"
    first_ifd_offset_binary = Binary.int32u_to_current(8)
    length = 2 + byte_size(@exif_header) + byte_size(byte_order) + byte_size(tiff_header_marker) + byte_size(first_ifd_offset_binary) + byte_size(ifd_block)
    length_binary = Binary.int16u_to_big_endian(length)
    binary = <<
      0xff, 0xe1,
      length_binary::binary,
      @exif_header::binary,
      byte_order::binary,
      tiff_header_marker::binary,
      first_ifd_offset_binary::binary,
      ifd_block::binary
    >>
    :ok = IO.binwrite(io_device, binary)
  end

  defimpl Exiffer.Serialize do
    def write(app1, io_device) do
      Exiffer.Header.APP1.write(app1, io_device)
    end

    def binary(_app1) do
      <<>>
    end
  end
end
