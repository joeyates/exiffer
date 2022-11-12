defmodule Exiffer.Entry do
  @moduledoc """
  Documentation for `Exiffer.Entry`.
  """

  alias Exiffer.Binary
  alias Exiffer.Buffer
  alias Exiffer.OffsetBuffer

  @enforce_keys ~w(type format value)a
  defstruct ~w(type format value)a

  @format_string <<0x02, 0x00>>
  @format_int16u <<0x03, 0x00>>
  @format_int32u <<0x04, 0x00>>
  @format_rational_64u <<0x05, 0x00>>
  @format_inline_string <<0x07, 0x00>>
  @format_rational_64s <<0x0a, 0x00>>

  @format_name %{
    @format_string => "String",
    @format_int16u => "16-bit integer",
    @format_int32u => "32-bit integer",
    @format_rational_64u => "64-bit rational",
    @format_inline_string => "Inline String",
    @format_rational_64s => "64-bit signed rational"
  }

  @fake_size <<0x01, 0x00, 0x00, 0x00>>

  @entry %{
    <<0x01, 0x00>> => "GPSLatitudeRef",
    <<0x02, 0x00>> => "GPSLatitude",
    <<0x03, 0x00>> => "GPSLongitudeRef",
    <<0x04, 0x00>> => "GPSLongitude",
    <<0x05, 0x00>> => "GPSAltitudeRef",
    <<0x06, 0x00>> => "GPSAltitude",
    <<0x00, 0x01>> => "ImageWidth",
    <<0x01, 0x01>> => "ImageHeight",
    <<0x03, 0x01>> => "Compression",
    <<0x0f, 0x01>> => "Make",
    <<0x10, 0x01>> => "Model",
    <<0x12, 0x01>> => "Orientation",
    <<0x1a, 0x01>> => "XResolution",
    <<0x1b, 0x01>> => "YResolution",
    <<0x28, 0x01>> => "ResolutionUnit",
    <<0x31, 0x01>> => "Software",
    <<0x32, 0x01>> => "ModificationDate",
    <<0x01, 0x02>> => "ThumbnailOffset",
    <<0x02, 0x02>> => "ThumbnailLength",
    <<0x13, 0x02>> => "YcbcrPositioning",
    <<0x69, 0x87>> => "ExifOffset",
    <<0x25, 0x88>> => "GPSInfo",
    <<0x9a, 0x82>> => "ExposureTime",
    <<0x9d, 0x82>> => "FNumber",
    <<0x22, 0x88>> => "ExposureProgram",
    <<0x27, 0x88>> => "Iso",
    <<0x00, 0x90>> => "ExifVersion",
    <<0x03, 0x90>> => "DateTimeOriginal",
    <<0x04, 0x90>> => "CreateDate",
    <<0x10, 0x90>> => "OffsetTime",
    <<0x11, 0x90>> => "OffsetTimeOriginal",
    <<0x01, 0x92>> => "ShutterSpeedValue",
    <<0x02, 0x92>> => "ApertureValue",
    <<0x03, 0x92>> => "BrightnessValue",
    <<0x04, 0x92>> => "ExposureCompensation",
    <<0x05, 0x92>> => "MaxApertureValue",
    <<0x07, 0x92>> => "MeteringMode",
    <<0x09, 0x92>> => "Flash",
    <<0x0a, 0x92>> => "FocalLength",
    <<0x01, 0xa0>> => "ColorSpace",
    <<0x02, 0xa0>> => "ExifImageWidth",
    <<0x03, 0xa0>> => "ExifImageHeight",
    <<0x02, 0xa4>> => "ExposureMode",
    <<0x03, 0xa4>> => "WhiteBalance",
    <<0x04, 0xa4>> => "DigitalZoomRatio",
    <<0x05, 0xa4>> => "FocalLengthIn35mmFormat",
    <<0x06, 0xa4>> => "SceneCaptureType",
    <<0x20, 0xa4>> => "ImageUniqueId"
  }

  def new(%OffsetBuffer{} = buffer) do
    {tag, buffer} = OffsetBuffer.consume(buffer, 2)
    type = @entry[tag]
    if !type do
      IO.puts "Unknown tag #{inspect(tag)} found"
    end
    {value, format, buffer} = value(buffer)
    buffer = OffsetBuffer.skip(buffer, 10)
    {%__MODULE__{type: type, format: format, value: value}, buffer}
  end

  def format_name(%__MODULE__{format: format}) do
    @format_name[format]
  end

  defp value(
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<@format_string, length_binary::binary-size(4), offset_binary::binary-size(4), _rest::binary>>
      }
    } = buffer
  ) do
    string_length = Binary.little_endian_to_integer(length_binary)
    string_offset = Binary.little_endian_to_integer(offset_binary)
    {value, buffer} = OffsetBuffer.random(buffer, string_offset, string_length - 1)
    {value, @format_string, buffer}
  end

  defp value(
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<@format_int16u, @fake_size, value_binary::binary-size(4), _rest::binary>>
      }
    } = buffer
  ) do
    value = Binary.little_endian_to_integer(value_binary)
    {value, @format_int16u, buffer}
  end

  defp value(
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<@format_int32u, @fake_size, value_binary::binary-size(4), _rest::binary>>
      }
    } = buffer
  ) do
    value = Binary.little_endian_to_integer(value_binary)
    {value, @format_int32u, buffer}
  end

  defp value(
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<@format_rational_64u, count_binary::binary-size(4), offset_binary::binary-size(4), _rest::binary>>
      }
    } = buffer
  ) do
    rational_count = Binary.little_endian_to_integer(count_binary)
    value_offset = Binary.little_endian_to_integer(offset_binary)
    {<<rational_binaries::binary-size(rational_count * 8)>>, buffer} = OffsetBuffer.random(buffer, value_offset, rational_count * 8)
    value = Binary.to_rational(rational_binaries)
    {value, @format_rational_64u, buffer}
  end

  defp value(
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<@format_rational_64s, @fake_size, offset_binary::binary-size(4), _rest::binary>>
      }
    } = buffer
  ) do
    value_offset = Binary.little_endian_to_integer(offset_binary)
    {<<rational::binary-size(8)>>, buffer} = OffsetBuffer.random(buffer, value_offset, 8)
    value = Binary.to_signed_rational(rational)
    {value, @format_rational_64s, buffer}
  end

  defp value(
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<@format_inline_string, size_binary::binary-size(4), value_binary::binary-size(4), _rest::binary>>
      }
    } = buffer
  ) do
    size = Binary.little_endian_to_integer(size_binary)
    <<value::binary-size(size), _rest::binary>> = value_binary
    {value, @format_inline_string, buffer}
  end
end
