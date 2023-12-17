defmodule Exiffer.JPEG.Header.APP1.EXIF do
  @moduledoc """
  Documentation for `Exiffer.JPEG.Header.APP1.EXIF`.
  """

  require Logger

  alias Exiffer.Binary
  alias Exiffer.JPEG.IFDBlock
  import Exiffer.Logging, only: [integer: 1]

  @exif_header "Exif\0\0"
  @tiff_header_marker <<0x00, 0x2a>>
  @big_endian_marker "MM"
  @little_endian_marker "II"

  @enforce_keys ~w(byte_order ifd_block)a
  defstruct ~w(byte_order ifd_block)a

  defimpl Jason.Encoder  do
    @spec encode(%Exiffer.JPEG.Header.APP1.EXIF{}, Jason.Encode.opts()) :: String.t()
    def encode(entry, opts) do
      Jason.Encode.map(
        %{
          module: "Exiffer.JPEG.Header.APP1.EXIF",
          byte_order: entry.byte_order,
          ifd_block: entry.ifd_block
        },
        opts
      )
    end
  end

  def new(%{data: <<length_bytes::binary-size(2), @exif_header::binary, _rest::binary>>} = buffer) do
    exif_start = Exiffer.Buffer.tell(buffer)
    buffer = Exiffer.Buffer.skip(buffer, 2 + String.length(@exif_header))
    length = Binary.big_endian_to_integer(length_bytes)
    Logger.debug("APP1 - length: #{length}")
    {byte_order_marker, buffer} = Exiffer.Buffer.consume(buffer, 2)
    Logger.debug("EXIF.new - byte order marker: #{byte_order_marker}")
    byte_order = case byte_order_marker do
       @big_endian_marker -> :big
       @little_endian_marker -> :little
       _ -> raise "Unknown byte order marker: #{byte_order_marker}"
    end
    Logger.debug "EXIF.new - setting byte order to :#{byte_order}"
    previous_byte_order = Binary.byte_order()
    Binary.set_byte_order(byte_order)
    tiff_header_marker = Binary.big_endian_to_current(@tiff_header_marker)
    {<<^tiff_header_marker::binary-size(2), ifd_header_offset_binary::binary-size(4)>>, buffer} = Exiffer.Buffer.consume(buffer, 6)
    ifd_header_offset = Binary.to_integer(ifd_header_offset_binary)
    offset = exif_start + ifd_header_offset
    {ifd_block, buffer} = IFDBlock.new(buffer, offset)
    exif = %__MODULE__{byte_order: byte_order, ifd_block: ifd_block}
    exif_end = exif_start + length
    Logger.debug "APP1 read completed, seeking to #{integer(exif_end)}"
    buffer = Exiffer.Buffer.seek(buffer, exif_end)
    Logger.debug "EXIF.new - resetting byte order to previous value: :#{previous_byte_order}"
    Binary.set_byte_order(previous_byte_order)
    {exif, buffer}
  end

  def binary(%__MODULE__{} = exif) do
    Logger.debug "APP1.EXIF.binary/1 - setting byte order to #{exif.byte_order}"
    previous_byte_order = Binary.byte_order()
    Binary.set_byte_order(exif.byte_order)
    tiff_header_marker = Binary.big_endian_to_current(@tiff_header_marker)
    ifd_block = IFDBlock.binary(exif.ifd_block)
    byte_order = if exif.byte_order == :big, do: "MM", else: "II"
    first_ifd_offset_binary = Binary.int32u_to_current(8)
    length = 2 + byte_size(@exif_header) + byte_size(byte_order) + byte_size(tiff_header_marker) + byte_size(first_ifd_offset_binary) + byte_size(ifd_block)
    length_binary = Binary.int16u_to_big_endian(length)
    Logger.debug "APP1.EXIF.binary/1 - resetting byte order to previous value: :#{previous_byte_order}"
    Binary.set_byte_order(previous_byte_order)
    <<
      0xff, 0xe1,
      length_binary::binary,
      @exif_header::binary,
      byte_order::binary,
      tiff_header_marker::binary,
      first_ifd_offset_binary::binary,
      ifd_block::binary
    >>
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
    Logger.debug "Writing EXIF header"
    binary = binary(exif)
    :ok = IO.binwrite(io_device, binary)
  end

  defimpl Exiffer.Serialize do
    alias Exiffer.JPEG.Header.APP1.EXIF

    def write(exif, io_device) do
      EXIF.write(exif, io_device)
    end

    def binary(exif) do
      EXIF.binary(exif)
    end

    def puts(exif) do
      EXIF.puts(exif)
    end
  end
end
