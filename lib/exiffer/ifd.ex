defmodule Exiffer.IFD do
  @moduledoc """
  Documentation for `Exiffer.IFDs`.
  """

  import Exiffer.Binary, only: [little_endian_to_decimal: 1]
  import Exiffer.OffsetBuffer, only: [consume: 2, seek: 2, skip: 2, random: 3, tell: 1]
  alias Exiffer.Buffer
  alias Exiffer.OffsetBuffer

  def read(%OffsetBuffer{} = buffer) do
    {<<ifd_count_bytes::binary-size(2)>>, buffer} = consume(buffer, 2)
    ifd_count = little_endian_to_decimal(ifd_count_bytes)
    {buffer, ifd_entries} = read_entry(buffer, ifd_count, [])
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

  @ifd_tag_exposure_time <<0x9a, 0x82>>

  @ifd_format_string <<0x02, 0x00>>
  @ifd_format_int16u <<0x03, 0x00>>
  @ifd_format_int32u <<0x04, 0x00>>
  @ifd_format_rational_64u <<0x05, 0x00>>

  @ifd_fake_size <<0x01, 0x00, 0x00, 0x00>>

  def read_entry(buffer, 0, ifd_entries) do
    {buffer, ifd_entries}
  end

  def read_entry(
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<@ifd_tag_image_width, @ifd_format_int32u, @ifd_fake_size, value_binary::binary-size(4), _rest::binary>>
      }
    } = buffer,
    count,
    ifd_entries
  ) do
    value = little_endian_to_decimal(value_binary)
    entry = %{
      type: "ImageWidth",
      value: value
    }
    IO.puts "Entry #{count}, ImageWidth at #{Integer.to_string(buffer.buffer.position, 16)}"

    buffer
    |> skip(12)
    |> read_entry(count - 1, [entry | ifd_entries])
  end

  def read_entry(
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<@ifd_tag_image_height, @ifd_format_int32u, @ifd_fake_size, value_binary::binary-size(4), _rest::binary>>
      }
    } = buffer,
    count,
    ifd_entries
  ) do
    IO.puts "Entry #{count}, ImageHeight at #{Integer.to_string(buffer.buffer.position, 16)}"
    value = little_endian_to_decimal(value_binary)
    entry = %{
      type: "ImageHeight",
      value: value
    }

    buffer
    |> skip(12)
    |> read_entry(count - 1, [entry | ifd_entries])
  end

  def read_entry(
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<@ifd_tag_compression, @ifd_format_int16u, @ifd_fake_size, value_binary::binary-size(4), _rest::binary>>
      }
    } = buffer,
    count,
    ifd_entries
  ) do
    IO.puts "Entry #{count}, Compression at #{Integer.to_string(buffer.buffer.position, 16)}"
    value = little_endian_to_decimal(value_binary)
    entry = %{
      type: "Compression",
      value: value
    }

    buffer
    |> skip(12)
    |> read_entry(count - 1, [entry | ifd_entries])
  end

  def read_entry(
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<@ifd_tag_make, @ifd_format_string, length_binary::binary-size(4), string_offset_binary::binary-size(4), _rest::binary>>
      }
    } = buffer,
    count,
    ifd_entries
  ) do
    IO.puts "Entry #{count}, Make at #{Integer.to_string(buffer.buffer.position, 16)}"
    string_offset = little_endian_to_decimal(string_offset_binary)
    string_length = little_endian_to_decimal(length_binary)
    {make, buffer} = random(buffer, string_offset, string_length - 1)
    entry = %{
      type: "Make",
      value: make
    }

    buffer
    |> skip(12)
    |> read_entry(count - 1, [entry | ifd_entries])
  end

  def read_entry(
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<@ifd_tag_model, @ifd_format_string, length_binary::binary-size(4), string_offset_binary::binary-size(4), _rest::binary>>
      }
    } = buffer,
    count,
    ifd_entries
  ) do
    IO.puts "Entry #{count}, Model at #{Integer.to_string(buffer.buffer.position, 16)}"
    string_offset = little_endian_to_decimal(string_offset_binary)
    string_length = little_endian_to_decimal(length_binary)
    {model, buffer} = random(buffer, string_offset, string_length - 1)
    entry = %{
      type: "Model",
      value: model
    }

    buffer
    |> skip(12)
    |> read_entry(count - 1, [entry | ifd_entries])
  end

  def read_entry(
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<@ifd_tag_orientation, @ifd_format_int16u, @ifd_fake_size, value_binary::binary-size(4), _rest::binary>>
      }
    } = buffer,
    count,
    ifd_entries
  ) do
    IO.puts "Entry #{count}, Orientation at #{Integer.to_string(buffer.buffer.position, 16)}"
    value = little_endian_to_decimal(value_binary)
    entry = %{
      type: "Orientation",
      value: value
    }

    buffer
    |> skip(12)
    |> read_entry(count - 1, [entry | ifd_entries])
  end

  def read_entry(
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<@ifd_tag_x_resolution, @ifd_format_rational_64u, @ifd_fake_size, offset_binary::binary-size(4), _rest::binary>>
      }
    } = buffer,
    count,
    ifd_entries
  ) do
    IO.puts "Entry #{count}, XResolution at #{Integer.to_string(buffer.buffer.position, 16)}"
    value_offset = little_endian_to_decimal(offset_binary)
    {<<high_binary::binary-size(4), low_binary::binary-size(4)>>, buffer} = random(buffer, value_offset, 8)
    entry = %{
      type: "XResolution",
      high: little_endian_to_decimal(high_binary),
      low: little_endian_to_decimal(low_binary)
    }

    buffer
    |> skip(12)
    |> read_entry(count - 1, [entry | ifd_entries])
  end

  def read_entry(
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<@ifd_tag_y_resolution, @ifd_format_rational_64u, @ifd_fake_size, offset_binary::binary-size(4), _rest::binary>>
      }
    } = buffer,
    count,
    ifd_entries
  ) do
    IO.puts "Entry #{count}, YResolution at #{Integer.to_string(buffer.buffer.position, 16)}"
    value_offset = little_endian_to_decimal(offset_binary)
    {<<high_binary::binary-size(4), low_binary::binary-size(4)>>, buffer} = random(buffer, value_offset, 8)
    entry = %{
      type: "YResolution",
      high: little_endian_to_decimal(high_binary),
      low: little_endian_to_decimal(low_binary)
    }

    buffer
    |> skip(12)
    |> read_entry(count - 1, [entry | ifd_entries])
  end

  def read_entry(
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<@ifd_tag_resolution_unit, @ifd_format_int16u, @ifd_fake_size, value_binary::binary-size(4), _rest::binary>>
      }
    } = buffer,
    count,
    ifd_entries
  ) do
    IO.puts "Entry #{count}, ResolutionUnit at #{Integer.to_string(buffer.buffer.position, 16)}"
    value = little_endian_to_decimal(value_binary)
    entry = %{
      type: "ResolutionUnit",
      value: value
    }

    buffer
    |> skip(12)
    |> read_entry(count - 1, [entry | ifd_entries])
  end

  def read_entry(
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<@ifd_tag_software, @ifd_format_string, length_binary::binary-size(4), string_offset_binary::binary-size(4), _rest::binary>>
      }
    } = buffer,
    count,
    ifd_entries
  ) do
    IO.puts "Entry #{count}, Software at #{Integer.to_string(buffer.buffer.position, 16)}"
    string_offset = little_endian_to_decimal(string_offset_binary)
    string_length = little_endian_to_decimal(length_binary)
    {value, buffer} = random(buffer, string_offset, string_length - 1)
    entry = %{
      type: "Software",
      value: value
    }

    buffer
    |> skip(12)
    |> read_entry(count - 1, [entry | ifd_entries])
  end

  def read_entry(
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<@ifd_tag_modification_date, @ifd_format_string, length_binary::binary-size(4), string_offset_binary::binary-size(4), _rest::binary>>
      }
    } = buffer,
    count,
    ifd_entries
  ) do
    IO.puts "Entry #{count}, ModificationDate at #{Integer.to_string(buffer.buffer.position, 16)}"
    string_offset = little_endian_to_decimal(string_offset_binary)
    string_length = little_endian_to_decimal(length_binary)
    {value, buffer} = random(buffer, string_offset, string_length - 1)
    entry = %{
      type: "ModificationDate",
      value: value
    }

    buffer
    |> skip(12)
    |> read_entry(count - 1, [entry | ifd_entries])
  end

  def read_entry(
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<@ifd_tag_thumbnail_offset, @ifd_format_int32u, @ifd_fake_size, value_binary::binary-size(4), _rest::binary>>
      }
    } = buffer,
    count,
    ifd_entries
  ) do
    IO.puts "Entry #{count}, ThumbnailOffset at #{Integer.to_string(buffer.buffer.position, 16)}"
    value = little_endian_to_decimal(value_binary)
    entry = %{
      type: "ThumbnailOffset",
      value: value
    }

    buffer
    |> skip(12)
    |> read_entry(count - 1, [entry | ifd_entries])
  end

  def read_entry(
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<@ifd_tag_thumbnail_length, @ifd_format_int32u, @ifd_fake_size, value_binary::binary-size(4), _rest::binary>>
      }
    } = buffer,
    count,
    ifd_entries
  ) do
    IO.puts "Entry #{count}, ThumbnailLength at #{Integer.to_string(buffer.buffer.position, 16)}"
    value = little_endian_to_decimal(value_binary)
    entry = %{
      type: "ThumbnailLength",
      value: value
    }

    buffer
    |> skip(12)
    |> read_entry(count - 1, [entry | ifd_entries])
  end

  def read_entry(
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<@ifd_tag_ycbcr_positioning, @ifd_format_int16u, @ifd_fake_size, value_binary::binary-size(4), _rest::binary>>
      }
    } = buffer,
    count,
    ifd_entries
  ) do
    IO.puts "Entry #{count}, YCbCrPositioning at #{Integer.to_string(buffer.buffer.position, 16)}"
    value = little_endian_to_decimal(value_binary)
    entry = %{
      type: "YCbCrPositioning",
      value: value
    }

    buffer
    |> skip(12)
    |> read_entry(count - 1, [entry | ifd_entries])
  end

  def read_entry(
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<@ifd_tag_exif_offset, @ifd_format_int32u, @ifd_fake_size, value_binary::binary-size(4), _rest::binary>>
      }
    } = buffer,
    count,
    ifd_entries
  ) do
    IO.puts "Entry #{count}, ExifOffset (#{count}) at #{Integer.to_string(buffer.buffer.position, 16)}"
    position = tell(buffer)
    exif_offset = little_endian_to_decimal(value_binary)
    buffer = seek(buffer, exif_offset)
    {buffer, ifd} = read(buffer)
    entry = %{
      type: "ExifOffset",
      value: exif_offset,
      ifd: ifd
    }

    next_entry_position = position + 12
    IO.puts "next_entry_position: #{Integer.to_string(next_entry_position, 16)}"

    buffer
    |> seek(next_entry_position)
    |> read_entry(count - 1, [entry | ifd_entries])
  end

  def read_entry(
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<@ifd_tag_gps_info, @ifd_format_int32u, @ifd_fake_size, value_binary::binary-size(4), _rest::binary>>
      }
    } = buffer,
    count,
    ifd_entries
  ) do
    IO.puts "Entry #{count}, GPSInfo at #{Integer.to_string(buffer.buffer.position, 16)}"
    value = little_endian_to_decimal(value_binary)
    entry = %{
      type: "GPSInfo",
      value: value
    }

    buffer
    |> skip(12)
    |> read_entry(count - 1, [entry | ifd_entries])
  end

  def read_entry(
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<@ifd_tag_exposure_time, @ifd_format_rational_64u, @ifd_fake_size, value_binary::binary-size(4), _rest::binary>>
      }
    } = buffer,
    count,
    ifd_entries
  ) do
    IO.puts "Entry #{count}, ExposureTime at #{Integer.to_string(buffer.buffer.position, 16)}"
    value = little_endian_to_decimal(value_binary)
    entry = %{
      type: "ExposureTime",
      value: value
    }

    buffer
    |> skip(12)
    |> read_entry(count - 1, [entry | ifd_entries])
  end

  def read_entry(
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<tag_bytes::binary-size(2), type_bytes::binary-size(2), size_bytes::binary-size(4), value_bytes::binary-size(4), _rest::binary>>,
      }
    } = buffer,
    count,
    ifd_entries
  ) do
    tag = little_endian_to_decimal(tag_bytes)
    IO.puts "Entry #{count}, Unknown Tag #{Integer.to_string(tag, 16)} at #{Integer.to_string(buffer.buffer.position, 16)}"
    entry = %{
      type: "Unknown IFD",
      tag: tag_bytes,
      data_type: type_bytes,
      size: size_bytes,
      value: value_bytes
    }

    buffer
    |> skip(12)
    |> read_entry(count - 1, [entry | ifd_entries])
  end
end
