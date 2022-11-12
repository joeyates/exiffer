defmodule Exiffer.JPEG do
  @moduledoc """
  Documentation for `Exiffer.JPEG`.
  """

  alias Exiffer.Binary
  alias Exiffer.Buffer
  alias Exiffer.IFDs

  @doc """
  Parse JPEG headers.
  """
  def headers(buffer, headers)

  def headers(%Buffer{data: <<0xff, 0xc0, length_bytes::binary-size(2), _rest::binary>>} = buffer, headers) do
    IO.puts "SOF0"
    buffer = Buffer.skip(buffer, 4)
    length = Binary.big_endian_to_integer(length_bytes)
    binary_length = length - 2
    {data, buffer} = Buffer.consume(buffer, binary_length)
    header = %{type: "JPEG SOF0", data: data}
    headers(buffer, [header | headers])
  end

  def headers(%Buffer{data: <<0xff, 0xc4, length_bytes::binary-size(2), _rest::binary>>} = buffer, headers) do
    IO.puts "DHT"
    buffer = Buffer.skip(buffer, 4)
    length = Binary.big_endian_to_integer(length_bytes)
    dht_length = length - 2
    {data, buffer} = Buffer.consume(buffer, dht_length)
    header = %{type: "JPEG DHT", dht: data}
    headers(buffer, [header | headers])
  end

  def headers(%Buffer{data: <<0xff, 0xda, _rest::binary>>} = buffer, headers) do
    IO.puts "SOS - Image data"
    header = %{type: "JPEG SOS"}
    {buffer, [header | headers]}
  end

  # DRI header
  def headers(%Buffer{data: <<0xff, 0xdd, length_bytes::binary-size(2), _rest::binary>>} = buffer, headers) do
    IO.puts "DRI"
    buffer = Buffer.skip(buffer, 4)
    length = Binary.big_endian_to_integer(length_bytes)
    {data, buffer} = Buffer.consume(buffer, length - 2)
    header = %{
      type: "JPEG DRI",
      comment: "Define Restart Interval",
      data: data
    }
    headers(buffer, [header | headers])
  end

  def headers(%Buffer{data: <<0xff, 0xdb, length_bytes::binary-size(2), _rest::binary>>} = buffer, headers) do
    IO.puts "DQT"
    buffer = Buffer.skip(buffer, 4)
    length = Binary.big_endian_to_integer(length_bytes)
    binary_length = length - 2
    {data, buffer} = Buffer.consume(buffer, binary_length)
    header = %{type: "JPEG DQT", dqt: data}
    headers(buffer, [header | headers])
  end

  def headers(
    %Buffer{
      data: <<
      0xff,
      0xe0,
      length::binary-size(2),
      "JFIF",
      version::binary-size(2),
      density_units,
      x_density::binary-size(2),
      y_density::binary-size(2),
      x_thumbnail,
      y_thumbnail,
      0x00,
      _rest::binary
      >> = buffer
    },
    headers
  ) do
    IO.puts "JFIF"
    buffer = Buffer.skip(buffer, 18)
    thumbnail_bytes = 3 * x_thumbnail * y_thumbnail
    {thumbnail, buffer} = Buffer.consume(buffer, thumbnail_bytes)
    header = %{
      type: "JFIF APP0",
      length: Binary.little_endian_to_integer(length),
      version: version,
      density_units: density_units,
      x_density: Binary.little_endian_to_integer(x_density),
      y_density: Binary.little_endian_to_integer(y_density),
      x_thumbnail: x_thumbnail,
      y_thumbnail: y_thumbnail,
      thumbnail: thumbnail
    }
    headers(buffer, [header | headers])
  end

  @tiff_header_marker <<0x2a, 0x00>>

  # APP1 header
  def headers(%Buffer{data: <<0xff, 0xe1, _rest::binary>>} = buffer, headers) do
    IO.puts "APP1"
    buffer = Buffer.skip(buffer, 2)
    app1_start = buffer.position
    {<<length_bytes::binary-size(2)>>, buffer} = Buffer.consume(buffer, 2)
    length = Binary.big_endian_to_integer(length_bytes)
    {"Exif\0\0", buffer} = Buffer.consume(buffer, 6)
    {<<byte_order::binary-size(2), @tiff_header_marker, ifd_header_offset_binary::binary-size(4)>>, buffer} = Buffer.consume(buffer, 8)
    ifd_header_offset = Binary.little_endian_to_integer(ifd_header_offset_binary)
    tiff_header = %{
      type: "TIFF Header Block",
      byte_order: byte_order,
      relative_ifd_header_offset: ifd_header_offset
    }
    offset = app1_start + ifd_header_offset
    ifds = IFDs.read(buffer, offset)
    {thumbnail, buffer} = IFDs.read_thumbnail(buffer, offset, ifds)
    {exif_ifd, buffer} = IFDs.read_ifd(buffer, offset, ifds, "ExifOffset")
    {gps_ifd, buffer} = IFDs.read_ifd(buffer, offset, ifds, "GPSInfo")
    app1_header = %{
      type: "APP1",
      length: length,
      ifds: ifds,
      thumbnail: thumbnail,
      exif_ifd: exif_ifd,
      gps_ifd: gps_ifd
    }
    # Skip to end of APP1
    buffer = Buffer.seek(buffer, app1_start + length)
    headers(buffer, headers ++ [app1_header, tiff_header])
  end

  # APP4 header
  def headers(%Buffer{data: <<0xff, 0xe4, length_bytes::binary-size(2), _rest::binary>>} = buffer, headers) do
    IO.puts "APP4"
    length = Binary.big_endian_to_integer(length_bytes)
    app4_header = %{
      type: "APP4",
      length: length
    }
    buffer = Buffer.skip(buffer, length + 2)
    headers(buffer, [app4_header | headers])
  end

  def headers(%Buffer{data: <<0xff, 0xfe, length_bytes::binary-size(2), _rest::binary>>} = buffer, headers) do
    IO.puts "COM"
    buffer = Buffer.skip(buffer, 4)
    length = Binary.big_endian_to_integer(length_bytes)
    {comment, buffer} = Buffer.consume(buffer, length - 2)
    buffer = Buffer.skip(buffer, 1)
    header = %{type: "JPEG COM Comment", comment: comment}
    headers(buffer, [header | headers])
  end
end
