defmodule Exiffer.JPEG do
  @moduledoc """
  Documentation for `Exiffer.JPEG`.
  """

  import Exiffer.Binary

  @doc """
  Parse JPEG headers.
  """
  def headers(data, headers)

  def headers(<<0xff, 0xc0, _unknown, length, rest::binary>>, headers) do
    IO.puts "SOF0"
    binary_length = length - 3
    <<body::binary-size(binary_length), rest2::binary>> = rest
    {rest3, data} = Exiffer.Binary.consume_until(0xff, rest2, "")
    header = %{type: "JPEG SOF0", body: body, data: data}
    {rest4, headers} = headers(rest3, headers)
    {rest4, [header | headers]}
  end

  def headers(<<0xff, 0xc4, _unknown, length, rest::binary>>, headers) do
    IO.puts "DHT"
    dht_length = length - 3
    <<dht::binary-size(dht_length), rest2::binary>> = rest
    {rest3, data} = Exiffer.Binary.consume_until(0xff, rest2, "")
    header = %{type: "JPEG DHT", dht: dht, data: data}
    {rest4, headers} = headers(rest3, headers)
    {rest4, [header | headers]}
  end

  def headers(<<0xff, 0xda, rest::binary>>, headers) do
    IO.puts "SOS - Image data"
    header = %{type: "JPEG SOS"}
    {rest, [header | headers]}
  end

  # DRI header
  def headers(<<0xff, 0xdd, length_bytes::binary-size(2), _rest::binary>> = binary, headers) do
    IO.puts "DRI"
    length = big_endian_to_decimal(length_bytes)
    header = %{
      type: "JPEG DRI",
      comment: "Define Restart Interval",
      length: length
    }
    <<_skip::binary-size(length + 2), rest::binary>> = binary
    {rest3, headers} = headers(rest, [header | headers])
    {rest3, headers}
  end

  def headers(<<0xff, 0xdb, _unknown, length, rest::binary>>, headers) do
    IO.puts "DQT"
    dqt_length = length - 3
    <<dqt::binary-size(dqt_length), rest2::binary>> = rest
    {rest3, data} = Exiffer.Binary.consume_until(0xff, rest2, "")
    header = %{type: "JPEG DQT", dqt: dqt, data: data}
    {rest4, headers} = headers(rest3, headers)
    {rest4, [header | headers]}
  end

  def headers(
    <<
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
    rest::binary
    >>,
    headers
  ) do
    IO.puts "JFIF"
    thumbnail_bytes = 3 * x_thumbnail * y_thumbnail
    <<thumbnail::binary-size(thumbnail_bytes), rest2::binary>> = rest
    header = %{
      type: "JFIF APP0",
      length: Exiffer.Binary.little_endian_to_decimal(length),
      version: version,
      density_units: density_units,
      x_density: Exiffer.Binary.little_endian_to_decimal(x_density),
      y_density: Exiffer.Binary.little_endian_to_decimal(y_density),
      x_thumbnail: x_thumbnail,
      y_thumbnail: y_thumbnail,
      thumbnail: thumbnail
    }
    {rest3, headers} = headers(rest2, headers)
    {rest3, [header | headers]}
  end

  @tiff_header_marker <<0x2a, 0x00>>

  # APP1 header
  def headers(<<0xff, 0xe1, app1_length_bytes::binary-size(2), "Exif\0\0", rest::binary>> = binary, headers) do
    IO.puts "APP1"
    app1_length = big_endian_to_decimal(app1_length_bytes)
    app1_header = %{
      type: "APP1",
      length: app1_length
    }
    <<byte_order::binary-size(2), @tiff_header_marker, ifd_header_offset::binary-size(4), rest2::binary>> = rest
    offset = Exiffer.Binary.little_endian_to_decimal(ifd_header_offset)
    tiff_header = %{
      type: "TIFF Header Block",
      byte_order: byte_order,
      ifd_header_offset: offset
    }
    {{_rest, _offset}, ifds} = read_ifds({rest2, offset}, [])
    # Skip to end of APP1
    <<_skip::binary-size(app1_length + 2), rest3::binary>> = binary
    {rest3, headers} = headers(rest3, headers ++ ifds ++ [app1_header, tiff_header])
    {rest3, headers}
  end

  # APP4 header
  def headers(<<0xff, 0xe4, app4_length_bytes::binary-size(2), _rest::binary>> = binary, headers) do
    IO.puts "APP4"
    app4_length = big_endian_to_decimal(app4_length_bytes)
    app4_header = %{
      type: "APP4",
      length: app4_length
    }
    <<_skip::binary-size(app4_length + 2), rest::binary>> = binary
    {rest3, headers} = headers(rest, [app4_header | headers])
    {rest3, headers}
  end

  def headers(<<0xff, 0xfe, _unknown, length, rest::binary>>, headers) do
    IO.puts "COM"
    comment_length = length - 3
    <<comment::binary-size(comment_length), 0x00, rest2::binary>> = rest
    header = %{type: "JPEG COM Comment", comment: comment}
    {rest3, headers} = headers(rest2, headers)
    {rest3, [header | headers]}
  end

  def headers(rest, headers) do
    {rest, headers}
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

  def read_ifds({binary, offset}, ifds) do
    {{rest, offset}, ifd} = read_ifd({binary, offset})
    <<next_ifd_bytes::binary-size(4), rest2::binary>> = rest
    offset = offset + 4
    next_ifd = Exiffer.Binary.little_endian_to_decimal(next_ifd_bytes)
    if next_ifd == 0 do
      {{rest, offset}, [ifd | ifds]}
    else
      skip_count = next_ifd - offset
      <<_skip::binary-size(skip_count), rest3::binary>> = rest2
      offset = next_ifd
      read_ifds({rest3, offset}, [ifd | ifds])
    end
  end

  def read_ifd({<<ifd_count_bytes::binary-size(2), rest::binary>>, offset}) do
    offset = offset + 2
    ifd_count = Exiffer.Binary.little_endian_to_decimal(ifd_count_bytes)
    {{rest2, _offset}, ifd_entries} = read_ifd_entry({rest, offset}, ifd_count, [])
    ifd = %{
      type: "IFD",
      entries: Enum.reverse(ifd_entries),
      count: ifd_count
    }
    post_ifd_entries_offset = offset + ifd_count * (2 + 2 + 4 + 4)
    {{rest2, post_ifd_entries_offset}, ifd}
  end

  def read_ifd_entry({binary, offset}, 0, ifd_entries), do: {{binary, offset}, ifd_entries}

  def read_ifd_entry(
    {
    <<@ifd_tag_image_width, @ifd_format_int32u, @ifd_fake_size, value_binary::binary-size(4), rest::binary>>,
    offset
    },
    count,
    ifd_entries
  ) do
    entry = %{
      type: "ImageWidth",
      value: value_binary
    }
    read_ifd_entry({rest, offset + 12}, count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    {
    <<@ifd_tag_image_height, @ifd_format_int32u, @ifd_fake_size, value_binary::binary-size(4), rest::binary>>,
    offset
    },
    count,
    ifd_entries
  ) do
    entry = %{
      type: "ImageHeight",
      value: value_binary
    }
    read_ifd_entry({rest, offset + 12}, count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    {
    <<@ifd_tag_compression, @ifd_format_int16u, @ifd_fake_size, value_binary::binary-size(4), rest::binary>>,
    offset
    },
    count,
    ifd_entries
  ) do
    entry = %{
      type: "Compression",
      value: value_binary
    }
    read_ifd_entry({rest, offset + 12}, count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    {
    <<@ifd_tag_make, @ifd_format_string, length_binary::binary-size(4), string_offset_binary::binary-size(4), rest::binary>> = binary,
    offset
    },
    count,
    ifd_entries
  ) do
    string_offset = Exiffer.Binary.little_endian_to_decimal(string_offset_binary)
    string_length = Exiffer.Binary.little_endian_to_decimal(length_binary)
    make = read_string({binary, offset}, string_offset, string_length)
    entry = %{
      type: "Make",
      value: make
    }
    read_ifd_entry({rest, offset + 12}, count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    {
    <<@ifd_tag_model, @ifd_format_string, length_binary::binary-size(4), string_offset_binary::binary-size(4), rest::binary>> = binary,
    offset
    },
    count,
    ifd_entries
  ) do
    string_offset = Exiffer.Binary.little_endian_to_decimal(string_offset_binary)
    string_length = Exiffer.Binary.little_endian_to_decimal(length_binary)
    model = read_string({binary, offset}, string_offset, string_length)
    entry = %{
      type: "Model",
      value: model
    }
    read_ifd_entry({rest, offset + 12}, count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    {
    <<@ifd_tag_orientation, @ifd_format_int16u, @ifd_fake_size, value_binary::binary-size(4), rest::binary>>,
    offset
    },
    count,
    ifd_entries
  ) do
    entry = %{
      type: "Orientation",
      value: value_binary
    }
    read_ifd_entry({rest, offset + 12}, count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    {
    <<@ifd_tag_x_resolution, @ifd_format_rational_64u, @ifd_fake_size, offset_binary::binary-size(4), rest::binary>>,
    offset
    },
    count,
    ifd_entries
  ) do
    entry = %{
      type: "XResolution",
      value: offset_binary
    }
    read_ifd_entry({rest, offset + 12}, count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    {
    <<@ifd_tag_y_resolution, @ifd_format_rational_64u, @ifd_fake_size, offset_binary::binary-size(4), rest::binary>>,
    offset
    },
    count,
    ifd_entries
  ) do
    entry = %{
      type: "YResolution",
      value: offset_binary
    }
    read_ifd_entry({rest, offset + 12}, count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    {
    <<@ifd_tag_resolution_unit, @ifd_format_int16u, @ifd_fake_size, value_binary::binary-size(4), rest::binary>>,
    offset
    },
    count,
    ifd_entries
  ) do
    entry = %{
      type: "ResolutionUnit",
      value: value_binary
    }
    read_ifd_entry({rest, offset + 12}, count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    {
    <<@ifd_tag_software, @ifd_format_string, length_binary::binary-size(4), string_offset_binary::binary-size(4), rest::binary>> = binary,
    offset
    },
    count,
    ifd_entries
  ) do
    string_offset = Exiffer.Binary.little_endian_to_decimal(string_offset_binary)
    string_length = Exiffer.Binary.little_endian_to_decimal(length_binary)
    value = read_string({binary, offset}, string_offset, string_length)
    entry = %{
      type: "Software",
      value: value
    }
    read_ifd_entry({rest, offset + 12}, count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    {
    <<@ifd_tag_modification_date, @ifd_format_string, length_binary::binary-size(4), string_offset_binary::binary-size(4), rest::binary>> = binary,
    offset
    },
    count,
    ifd_entries
  ) do
    string_offset = Exiffer.Binary.little_endian_to_decimal(string_offset_binary)
    string_length = Exiffer.Binary.little_endian_to_decimal(length_binary)
    value = read_string({binary, offset}, string_offset, string_length)
    entry = %{
      type: "ModificationDate",
      value: value
    }
    read_ifd_entry({rest, offset + 12}, count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    {
    <<@ifd_tag_thumbnail_offset, @ifd_format_int32u, @ifd_fake_size, value_binary::binary-size(4), rest::binary>>,
    offset
    },
    count,
    ifd_entries
  ) do
    entry = %{
      type: "ThumbnailOffset",
      value: value_binary
    }
    read_ifd_entry({rest, offset + 12}, count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    {
    <<@ifd_tag_thumbnail_length, @ifd_format_int32u, @ifd_fake_size, value_binary::binary-size(4), rest::binary>>,
    offset
    },
    count,
    ifd_entries
  ) do
    entry = %{
      type: "ThumbnailLength",
      value: value_binary
    }
    read_ifd_entry({rest, offset + 12}, count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    {
    <<@ifd_tag_ycbcr_positioning, @ifd_format_int16u, @ifd_fake_size, value_binary::binary-size(4), rest::binary>>,
    offset
    },
    count,
    ifd_entries
  ) do
    entry = %{
      type: "YCbCrPositioning",
      value: value_binary
    }
    read_ifd_entry({rest, offset + 12}, count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    {
    <<@ifd_tag_exif_offset, @ifd_format_int32u, @ifd_fake_size, value_binary::binary-size(4), rest::binary>>,
    offset
    },
    count,
    ifd_entries
  ) do
    entry = %{
      type: "ExifOffset",
      value: value_binary
    }
    read_ifd_entry({rest, offset + 12}, count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    {
    <<@ifd_tag_gps_info, @ifd_format_int32u, @ifd_fake_size, value_binary::binary-size(4), rest::binary>>,
    offset
    },
    count,
    ifd_entries
  ) do
    entry = %{
      type: "GPSInfo",
      value: value_binary
    }
    read_ifd_entry({rest, offset + 12}, count - 1, [entry | ifd_entries])
  end

  def read_ifd_entry(
    {
    <<tag_bytes::binary-size(2), type_bytes::binary-size(2), size_bytes::binary-size(2), rest::binary>>,
    offset
    },
    count,
    ifd_entries
  ) do
    tag = Exiffer.Binary.little_endian_to_decimal(tag_bytes)
    IO.puts "Unknown IFD Tag #{Integer.to_string(tag, 16)}"
    entry = %{
      type: "Unknown IFD",
      tag: tag_bytes,
      data_type: type_bytes,
      size: size_bytes
    }
    read_ifd_entry({rest, offset + 12}, count - 1, [entry | ifd_entries])
  end

  def read_string({binary, offset}, string_offset, string_length) do
    skip_count = string_offset - offset
    <<_skip::binary-size(skip_count), string::binary-size(string_length - 1), _rest::binary>> = binary
    string
  end
end
