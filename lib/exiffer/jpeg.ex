defmodule Exiffer.JPEG do
  @moduledoc """
  Documentation for `Exiffer.JPEG`.
  """

  import Exiffer.Binary
  import Exiffer.Buffer, only: [consume: 2, seek: 2, skip: 2]

  @doc """
  Parse JPEG headers.
  """
  def headers(buffer, headers)

  def headers(%Exiffer.Buffer{data: <<0xff, 0xc0, length_bytes::binary-size(2), _rest::binary>>} = buffer, headers) do
    IO.puts "SOF0"
    buffer = skip(buffer, 4)
    length = big_endian_to_decimal(length_bytes)
    binary_length = length - 2
    {data, buffer} = consume(buffer, binary_length)
    header = %{type: "JPEG SOF0", data: data}
    headers(buffer, [header | headers])
  end

  def headers(%Exiffer.Buffer{data: <<0xff, 0xc4, length_bytes::binary-size(2), _rest::binary>>} = buffer, headers) do
    IO.puts "DHT"
    buffer = skip(buffer, 4)
    length = big_endian_to_decimal(length_bytes)
    dht_length = length - 2
    {data, buffer} = consume(buffer, dht_length)
    header = %{type: "JPEG DHT", dht: data}
    headers(buffer, [header | headers])
  end

  def headers(%Exiffer.Buffer{data: <<0xff, 0xda, _rest::binary>>} = buffer, headers) do
    IO.puts "SOS - Image data"
    header = %{type: "JPEG SOS"}
    {buffer, [header | headers]}
  end

  # DRI header
  def headers(%Exiffer.Buffer{data: <<0xff, 0xdd, length_bytes::binary-size(2), _rest::binary>>} = buffer, headers) do
    IO.puts "DRI"
    buffer = skip(buffer, 4)
    length = big_endian_to_decimal(length_bytes)
    {data, buffer} = consume(buffer, length - 2)
    header = %{
      type: "JPEG DRI",
      comment: "Define Restart Interval",
      data: data
    }
    headers(buffer, [header | headers])
  end

  def headers(%Exiffer.Buffer{data: <<0xff, 0xdb, length_bytes::binary-size(2), _rest::binary>>} = buffer, headers) do
    IO.puts "DQT"
    buffer = skip(buffer, 4)
    length = big_endian_to_decimal(length_bytes)
    binary_length = length - 2
    {data, buffer} = consume(buffer, binary_length)
    header = %{type: "JPEG DQT", dqt: data}
    headers(buffer, [header | headers])
  end

  def headers(
    %Exiffer.Buffer{
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
    buffer = skip(buffer, 18)
    thumbnail_bytes = 3 * x_thumbnail * y_thumbnail
    {thumbnail, buffer} = consume(buffer, thumbnail_bytes)
    header = %{
      type: "JFIF APP0",
      length: little_endian_to_decimal(length),
      version: version,
      density_units: density_units,
      x_density: little_endian_to_decimal(x_density),
      y_density: little_endian_to_decimal(y_density),
      x_thumbnail: x_thumbnail,
      y_thumbnail: y_thumbnail,
      thumbnail: thumbnail
    }
    headers(buffer, [header | headers])
  end

  @tiff_header_marker <<0x2a, 0x00>>

  # APP1 header
  def headers(%Exiffer.Buffer{data: <<0xff, 0xe1, length_bytes::binary-size(2), _rest::binary>>} = buffer0, headers) do
    IO.puts "APP1"
    buffer = skip(buffer0, 4)
    <<"Exif\0\0", _rest::binary>> = buffer.data
    buffer = skip(buffer, 6)
    length = big_endian_to_decimal(length_bytes)
    app1_header = %{
      type: "APP1",
      length: length
    }
    <<byte_order::binary-size(2), @tiff_header_marker, ifd_header_offset::binary-size(4), _rest::binary>> = buffer.data
    buffer = skip(buffer, 8)
    length = big_endian_to_decimal(length_bytes)
    offset = little_endian_to_decimal(ifd_header_offset)
    tiff_header = %{
      type: "TIFF Header Block",
      byte_order: byte_order,
      ifd_header_offset: offset
    }
    {_buffer, ifds} = read_ifds(buffer, [], 4 + offset)
    # Skip to end of APP1
    # TODO: keeping a reference to buffer0 and using it again later is a bug.
    # The position of the underlying IO *may* have changed in the meantime.
    buffer = skip(buffer0, length + 2)
    headers(buffer, headers ++ ifds ++ [app1_header, tiff_header])
  end

  # APP4 header
  def headers(%Exiffer.Buffer{data: <<0xff, 0xe4, length_bytes::binary-size(2), _rest::binary>>} = buffer0, headers) do
    IO.puts "APP4"
    length = big_endian_to_decimal(length_bytes)
    app4_header = %{
      type: "APP4",
      length: length
    }
    buffer = skip(buffer0, length + 2)
    headers(buffer, [app4_header | headers])
  end

  def headers(%Exiffer.Buffer{data: <<0xff, 0xfe, length_bytes::binary-size(2), _rest::binary>>} = buffer, headers) do
    IO.puts "COM"
    buffer = skip(buffer, 4)
    length = big_endian_to_decimal(length_bytes)
    {comment, buffer} = consume(buffer, length - 2)
    buffer = skip(buffer, 1)
    header = %{type: "JPEG COM Comment", comment: comment}
    headers(buffer, [header | headers])
  end

  def headers(buffer, headers) do
    IO.puts "Unknown"
    Exiffer.Debug.dump("Unknown header", buffer.data)
    {buffer, headers}
  end

  def read_ifds(%Exiffer.Buffer{} = buffer, ifds, tiff_header_offset) do
    {buffer, ifd} = read_ifd(buffer)
    {next_ifd_bytes, buffer} = consume(buffer, 4)
    next_ifd = little_endian_to_decimal(next_ifd_bytes)
    if next_ifd == 0 do
      {buffer, [ifd | ifds]}
    else
      buffer = seek(buffer, tiff_header_offset + next_ifd)
      read_ifds(buffer, [ifd | ifds], tiff_header_offset)
    end
  end

  def read_ifd(%Exiffer.Buffer{data: <<ifd_count_bytes::binary-size(2), _rest::binary>>} = buffer) do
    buffer = skip(buffer, 2)
    ifd_count = little_endian_to_decimal(ifd_count_bytes)
    {buffer, ifd_entries} = read_ifd_entry(buffer, ifd_count, [])
    ifd = %{
      type: "IFD",
      entries: Enum.reverse(ifd_entries),
      count: ifd_count
    }
    {buffer, ifd}
  end

  @ifd_tag_image_width <<0x00, 0x01>>
  @ifd_tag_image_height <<0x01, 0x01>>
  @ifd_tag_compression <<0x03, 0x01>>
  @ifd_tag_make <<0x0f, 0x01>>
  @ifd_tag_model <<0x10, 0x01>>
  @ifd_tag_orientation <<0x12, 0x01>>
  @ifd_tag_x_resolution <<0x1a, 0x01>>
  @ifd_tag_y_resolution <<0x1b, 0x01>>
  @ifd_tag_resolution_unit <<0x28, 0x01>>
  @ifd_tag_software <<0x31, 0x01>>
  @ifd_tag_modification_date <<0x32, 0x01>>
  @ifd_tag_thumbnail_offset <<0x01, 0x02>>
  @ifd_tag_thumbnail_length <<0x02, 0x02>>
  @ifd_tag_ycbcr_positioning <<0x13, 0x02>>
  @ifd_tag_exif_offset <<0x69, 0x87>>
  @ifd_tag_gps_info <<0x25, 0x88>>

  @ifd_format_string <<0x02, 0x00>>
  @ifd_format_int16u <<0x03, 0x00>>
  @ifd_format_int32u <<0x04, 0x00>>
  @ifd_format_rational_64u <<0x05, 0x00>>

  @ifd_fake_size <<0x01, 0x00, 0x00, 0x00>>

  def read_ifd_entry(buffer, 0, ifd_entries) do
    Exiffer.Debug.dump("read_ifd_entry All entries read", buffer.data)
    {buffer, ifd_entries}
  end

  def read_ifd_entry(
    %Exiffer.Buffer{
      data: <<@ifd_tag_image_width, @ifd_format_int32u, @ifd_fake_size, value_binary::binary-size(4), _rest::binary>>
    } = buffer,
    count,
    ifd_entries
  ) do
    value = little_endian_to_decimal(value_binary)
    entry = %{
      type: "ImageWidth",
      value: value
    }

    buffer
    |> skip(12)
    |> read_ifd_entry(count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    %Exiffer.Buffer{
      data: <<@ifd_tag_image_height, @ifd_format_int32u, @ifd_fake_size, value_binary::binary-size(4), rest::binary>>
    } = buffer,
    count,
    ifd_entries
  ) do
    value = little_endian_to_decimal(value_binary)
    entry = %{
      type: "ImageHeight",
      value: value
    }

    buffer
    |> skip(12)
    |> read_ifd_entry(count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    %Exiffer.Buffer{
      data: <<@ifd_tag_compression, @ifd_format_int16u, @ifd_fake_size, value_binary::binary-size(4), rest::binary>>
    } = buffer,
    count,
    ifd_entries
  ) do
    entry = %{
      type: "Compression",
      value: value_binary
    }

    buffer
    |> skip(12)
    |> read_ifd_entry(count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    %Exiffer.Buffer{
      data: <<@ifd_tag_make, @ifd_format_string, length_binary::binary-size(4), string_offset_binary::binary-size(4), rest::binary>> = binary
    } = buffer,
    count,
    ifd_entries
  ) do
    string_offset = little_endian_to_decimal(string_offset_binary)
    string_length = little_endian_to_decimal(length_binary)
    make = read_string({binary, offset}, string_offset, string_length)
    entry = %{
      type: "Make",
      value: make
    }

    buffer
    |> skip(12)
    |> read_ifd_entry(count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    %Exiffer.Buffer{
      data: <<@ifd_tag_model, @ifd_format_string, length_binary::binary-size(4), string_offset_binary::binary-size(4), rest::binary>>
    } = buffer,
    count,
    ifd_entries
  ) do
    string_offset = little_endian_to_decimal(string_offset_binary)
    string_length = little_endian_to_decimal(length_binary)
    {model, buffer} = consume(buffer, string_length)
    buffer = skip(buffer, 1)
    entry = %{
      type: "Model",
      value: model
    }

    buffer
    |> skip(12)
    |> read_ifd_entry(count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    %Exiffer.Buffer{
      data: <<@ifd_tag_orientation, @ifd_format_int16u, @ifd_fake_size, value_binary::binary-size(4), rest::binary>>
    } = buffer,
    count,
    ifd_entries
  ) do
    entry = %{
      type: "Orientation",
      value: value_binary
    }

    buffer
    |> skip(12)
    |> read_ifd_entry(count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    %Exiffer.Buffer{
      data: <<@ifd_tag_x_resolution, @ifd_format_rational_64u, @ifd_fake_size, offset_binary::binary-size(4), rest::binary>>
    } = buffer,
    count,
    ifd_entries
  ) do
    # TODO: values which are not inlined need to be read from the position indicated by offset_binary.
    # This requires a modification to Buffer to read a value at an offset, but keep the existing buffer
    # contents as is. Maybe Buffer.read_at/2
    entry = %{
      type: "XResolution",
      value: offset_binary
    }

    buffer
    |> skip(12)
    |> read_ifd_entry(count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    %Exiffer.Buffer{
      data: <<@ifd_tag_y_resolution, @ifd_format_rational_64u, @ifd_fake_size, offset_binary::binary-size(4), rest::binary>>
    } = buffer,
    count,
    ifd_entries
  ) do
    entry = %{
      type: "YResolution",
      value: offset_binary
    }

    buffer
    |> skip(12)
    |> read_ifd_entry(count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    %Exiffer.Buffer{
      data: <<@ifd_tag_resolution_unit, @ifd_format_int16u, @ifd_fake_size, value_binary::binary-size(4), rest::binary>>
    } = buffer,
    count,
    ifd_entries
  ) do
    entry = %{
      type: "ResolutionUnit",
      value: value_binary
    }

    buffer
    |> skip(12)
    |> read_ifd_entry(count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    %Exiffer.Buffer{
      data: <<@ifd_tag_software, @ifd_format_string, length_binary::binary-size(4), string_offset_binary::binary-size(4), rest::binary>> = binary
    } = buffer,
    count,
    ifd_entries
  ) do
    string_offset = little_endian_to_decimal(string_offset_binary)
    string_length = little_endian_to_decimal(length_binary)
    value = read_string({binary, offset}, string_offset, string_length)
    entry = %{
      type: "Software",
      value: value
    }

    buffer
    |> skip(12)
    |> read_ifd_entry(count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    %Exiffer.Buffer{
      data: <<@ifd_tag_modification_date, @ifd_format_string, length_binary::binary-size(4), string_offset_binary::binary-size(4), rest::binary>> = binary
    } = buffer,
    count,
    ifd_entries
  ) do
    string_offset = little_endian_to_decimal(string_offset_binary)
    string_length = little_endian_to_decimal(length_binary)
    value = read_string({binary, offset}, string_offset, string_length)
    entry = %{
      type: "ModificationDate",
      value: value
    }

    buffer
    |> skip(12)
    |> read_ifd_entry(count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    %Exiffer.Buffer{
      data: <<@ifd_tag_thumbnail_offset, @ifd_format_int32u, @ifd_fake_size, value_binary::binary-size(4), rest::binary>>
    } = buffer,
    count,
    ifd_entries
  ) do
    entry = %{
      type: "ThumbnailOffset",
      value: value_binary
    }

    buffer
    |> skip(12)
    |> read_ifd_entry(count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    %Exiffer.Buffer{
      data: <<@ifd_tag_thumbnail_length, @ifd_format_int32u, @ifd_fake_size, value_binary::binary-size(4), rest::binary>>
    } = buffer,
    count,
    ifd_entries
  ) do
    entry = %{
      type: "ThumbnailLength",
      value: value_binary
    }

    buffer
    |> skip(12)
    |> read_ifd_entry(count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    %Exiffer.Buffer{
      data: <<@ifd_tag_ycbcr_positioning, @ifd_format_int16u, @ifd_fake_size, value_binary::binary-size(4), rest::binary>>
    } = buffer,
    count,
    ifd_entries
  ) do
    entry = %{
      type: "YCbCrPositioning",
      value: value_binary
    }

    buffer
    |> skip(12)
    |> read_ifd_entry(count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    %Exiffer.Buffer{
      data: <<@ifd_tag_exif_offset, @ifd_format_int32u, @ifd_fake_size, value_binary::binary-size(4), rest::binary>>
    } = buffer,
    count,
    ifd_entries
  ) do
    entry = %{
      type: "ExifOffset",
      value: value_binary
    }

    buffer
    |> skip(12)
    |> read_ifd_entry(count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    %Exiffer.Buffer{
      data: <<@ifd_tag_gps_info, @ifd_format_int32u, @ifd_fake_size, value_binary::binary-size(4), rest::binary>>
    } = buffer,
    count,
    ifd_entries
  ) do
    entry = %{
      type: "GPSInfo",
      value: value_binary
    }

    buffer
    |> skip(12)
    |> read_ifd_entry(count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    %Exiffer.Buffer{
      data: <<tag_bytes::binary-size(2), type_bytes::binary-size(2), size_bytes::binary-size(4), value_bytes::binary-size(4), _rest::binary>>,
    } = buffer,
    count,
    ifd_entries
  ) do
    tag = little_endian_to_decimal(tag_bytes)
    IO.puts "Unknown IFD Tag #{Integer.to_string(tag, 16)}"
    entry = %{
      type: "Unknown IFD",
      tag: tag_bytes,
      data_type: type_bytes,
      size: size_bytes,
      value: value_bytes
    }

    buffer
    |> skip(12)
    |> read_ifd_entry(count - 1, [entry | ifd_entries])
  end
end
