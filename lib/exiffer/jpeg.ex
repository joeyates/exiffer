defmodule Exiffer.JPEG do
  @moduledoc """
  Documentation for `Exiffer.JPEG`.
  """

  alias Exiffer.Binary
  alias Exiffer.Buffer
  alias Exiffer.Header.APP1
  alias Exiffer.Header.APP4
  alias Exiffer.Header.Data
  alias Exiffer.Header.JFIF
  alias Exiffer.Header.SOS
  alias Exiffer.IFDs
  require Logger

  @doc """
  Parse JPEG headers.
  """
  def headers(buffer, headers)

  def headers(%Buffer{data: <<0xff, 0xda, _rest::binary>>} = buffer, headers) do
    header = %SOS{}
    {buffer, [header | headers]}
  end

  def headers(
    %Buffer{
      data: <<
        0xff,
        0xe0,
        _length_binary::binary-size(2),
        "JFIF",
        version::binary-size(2),
        density_units,
        x_density::binary-size(2),
        y_density::binary-size(2),
        x_thumbnail,
        y_thumbnail,
        0x00,
        _rest::binary
      >>
    } = buffer,
    headers
  ) do
    Logger.debug ~s(Header "JFIF" at #{Integer.to_string(buffer.position, 16)})
    buffer = Buffer.skip(buffer, 18)
    thumbnail_bytes = 3 * x_thumbnail * y_thumbnail
    {thumbnail, buffer} = Buffer.consume(buffer, thumbnail_bytes)
    header = %JFIF{
      type: "JFIF APP0",
      version: version,
      density_units: density_units,
      x_density: Binary.to_integer(x_density),
      y_density: Binary.to_integer(y_density),
      x_thumbnail: x_thumbnail,
      y_thumbnail: y_thumbnail,
      thumbnail: thumbnail
    }
    headers(buffer, [header | headers])
  end

  @tiff_header_marker <<0x00, 0x2a>>

  def headers(%Buffer{data: <<0xff, 0xe1, _rest::binary>>} = buffer, headers) do
    Logger.debug ~s(Header "APP1" at #{Integer.to_string(buffer.position, 16)})
    buffer = Buffer.skip(buffer, 2)
    app1_start = buffer.position
    {<<length_bytes::binary-size(2)>>, buffer} = Buffer.consume(buffer, 2)
    length = Binary.big_endian_to_integer(length_bytes)
    {"Exif\0\0", buffer} = Buffer.consume(buffer, 6)
    {byte_order_marker, buffer} = Buffer.consume(buffer, 2)
    byte_order = if byte_order_marker == "MM", do: :big, else: :little
    Binary.set_byte_order(byte_order)
    tiff_header_marker = Binary.big_endian_to_current(@tiff_header_marker)
    {<<^tiff_header_marker::binary-size(2), ifd_header_offset_binary::binary-size(4)>>, buffer} = Buffer.consume(buffer, 6)
    ifd_header_offset = Binary.to_integer(ifd_header_offset_binary)
    offset = app1_start + ifd_header_offset
    ifds = IFDs.read(buffer, offset)
    {thumbnail, buffer} = IFDs.read_thumbnail(buffer, offset, ifds)
    {exif_ifd, buffer} = IFDs.read_ifd(buffer, offset, ifds, :exif_offset)
    {gps_ifd, buffer} = IFDs.read_ifd(buffer, offset, ifds, :gps_info)
    app1_header = %APP1{
      byte_order: byte_order,
      ifds: ifds,
      thumbnail: thumbnail,
      exif_ifd: exif_ifd,
      gps_ifd: gps_ifd
    }
    app1_end = app1_start + length
    Logger.debug "APP1 read completed, seeking to #{Integer.to_string(app1_end, 16)}"
    buffer = Buffer.seek(buffer, app1_end)
    headers(buffer, [app1_header | headers])
  end

  def headers(%Buffer{data: <<0xff, 0xe4, length_bytes::binary-size(2), _rest::binary>>} = buffer, headers) do
    Logger.debug ~s(Header "APP4" at #{Integer.to_string(buffer.position, 16)})
    length = Binary.big_endian_to_integer(length_bytes)
    app4_header = %APP4{length: length}
    buffer = Buffer.skip(buffer, length + 2)
    headers(buffer, [app4_header | headers])
  end

  def headers(%Buffer{data: <<0xff, 0xfe, length_bytes::binary-size(2), _rest::binary>>} = buffer, headers) do
    Logger.debug ~s(Header "COM" at #{Integer.to_string(buffer.position, 16)})
    buffer = Buffer.skip(buffer, 4)
    length = Binary.big_endian_to_integer(length_bytes)
    {comment, buffer} = Buffer.consume(buffer, length - 2)
    buffer = Buffer.skip(buffer, 1)
    header = %Data{type: "JPEG COM Comment", data: comment}
    headers(buffer, [header | headers])
  end

  def headers(%Buffer{} = buffer, headers) do
    Logger.debug ~s(Header Data at #{Integer.to_string(buffer.position, 16)})
    {header, buffer} = Data.new(buffer)
    headers(buffer, [header | headers])
  end

  def write(%Buffer{} = _buffer, _headers) do
  end
end
