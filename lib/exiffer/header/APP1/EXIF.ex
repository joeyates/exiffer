defmodule Exiffer.Header.APP1.EXIF do
  @moduledoc """
  Documentation for `Exiffer.Header.APP1.EXIF`.
  """

  alias Exiffer.Binary
  alias Exiffer.Buffer
  alias Exiffer.IFDBlock
  require Logger

  @exif_header "Exif\0\0"
  @tiff_header_marker <<0x00, 0x2a>>
  @big_endian_marker "MM"

  @enforce_keys ~w(byte_order ifd_block)a
  defstruct ~w(byte_order ifd_block)a

  def new(%Buffer{data: <<length_bytes::binary-size(2), @exif_header::binary, _rest::binary>>} = buffer) do
    exif_start = buffer.position
    buffer = Buffer.skip(buffer, 2 + String.length(@exif_header))
    length = Binary.big_endian_to_integer(length_bytes)
    {byte_order_marker, buffer} = Buffer.consume(buffer, 2)
    byte_order = if byte_order_marker == @big_endian_marker, do: :big, else: :little
    Binary.set_byte_order(byte_order)
    tiff_header_marker = Binary.big_endian_to_current(@tiff_header_marker)
    {<<^tiff_header_marker::binary-size(2), ifd_header_offset_binary::binary-size(4)>>, buffer} = Buffer.consume(buffer, 6)
    ifd_header_offset = Binary.to_integer(ifd_header_offset_binary)
    offset = exif_start + ifd_header_offset
    {ifd_block, buffer} = IFDBlock.new(buffer, offset)
    exif = %__MODULE__{byte_order: byte_order, ifd_block: ifd_block}
    exif_end = exif_start + length
    Logger.debug "APP1.EXIF read completed, seeking to #{Integer.to_string(exif_end, 16)}"
    buffer = Buffer.seek(buffer, exif_end)
    {exif, buffer}
  end

  def puts(%__MODULE__{} = exif) do
    IO.puts "File"
    IO.puts "----"
    byte_order = if exif.byte_order == :big, do: "Big endian", else: "Little endian"
    IO.puts "Byte order: #{byte_order}"
    IO.puts "General"
    IO.puts "-------"
    IFDBlock.puts(exif.ifd_block)
    :ok
  end

  def write(%__MODULE__{} = exif, io_device) do
    tiff_header_marker = Binary.big_endian_to_current(@tiff_header_marker)
    ifd_block = IFDBlock.binary(exif.ifd_block)
    byte_order = if exif.byte_order == :big, do: "MM", else: "II"
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
    def write(exif, io_device) do
      Exiffer.Header.APP1.EXIF.write(exif, io_device)
    end

    def binary(_exif) do
      <<>>
    end

    def puts(exif) do
      Exiffer.Header.APP1.EXIF.puts(exif)
    end
  end
end
