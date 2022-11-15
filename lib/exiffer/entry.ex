defmodule Exiffer.Entry do
  @moduledoc """
  Documentation for `Exiffer.Entry`.
  """

  alias Exiffer.Binary
  alias Exiffer.Buffer
  alias Exiffer.Entry.MakerNotes
  alias Exiffer.IFD
  alias Exiffer.OffsetBuffer
  require Logger

  @enforce_keys ~w(type format value)a
  defstruct ~w(type format value)a

  # Binaries are big endian

  @format_string <<0x00, 0x02>>
  @format_int16u <<0x00, 0x03>>
  @format_int32u <<0x00, 0x04>>
  @format_rational_64u <<0x00, 0x05>>
  @format_inline_string <<0x00, 0x07>>
  @format_rational_64s <<0x00, 0x0a>>

  @format %{
    @format_string => %{type: :string, name: "String"},
    @format_int16u => %{type: :int16u, name: "16-bit integer"},
    @format_int32u => %{type: :int32u, name: "32-bit integer"},
    @format_rational_64u => %{type: :rational_64u, name: "64-bit rational"},
    @format_inline_string => %{type: :inline_string, name: "Inline String"},
    @format_rational_64s => %{type: :rational_64s, name: "64-bit signed rational"}
  }

  @format_name Enum.into(@format, %{}, fn {_k, %{type: type, name: name}} -> {type, name} end)

  @entry %{
    <<0x00, 0x00>> => %{type: :version, name: "Version"},
    <<0x00, 0x01>> => %{type: :gps_latitude_ref, name: "GPSLatitudeRef"},
    <<0x00, 0x02>> => %{type: :gps_latitude, name: "GPSLatitude"},
    <<0x00, 0x03>> => %{type: :gps_longitude_ref, name: "GPSLongitudeRef"},
    <<0x00, 0x04>> => %{type: :gps_longitude, name: "GPSLongitude"},
    <<0x00, 0x05>> => %{type: :gps_altitude_ref, name: "GPSAltitudeRef"},
    <<0x00, 0x06>> => %{type: :gps_altitude, name: "GPSAltitude"},
    <<0x01, 0x00>> => %{type: :image_width, name: "ImageWidth"},
    <<0x01, 0x01>> => %{type: :image_height, name: "ImageHeight"},
    <<0x01, 0x03>> => %{type: :compression, name: "Compression"},
    <<0x01, 0x0f>> => %{type: :make, name: "Make"},
    <<0x01, 0x10>> => %{type: :model, name: "Model"},
    <<0x01, 0x12>> => %{type: :orientation, name: "Orientation"},
    <<0x01, 0x1a>> => %{type: :x_resolution, name: "XResolution"},
    <<0x01, 0x1b>> => %{type: :y_resolution, name: "YResolution"},
    <<0x01, 0x28>> => %{type: :resolution_unit, name: "ResolutionUnit"},
    <<0x01, 0x31>> => %{type: :software, name: "Software"},
    <<0x01, 0x32>> => %{type: :modification_date, name: "ModificationDate"},
    <<0x02, 0x01>> => %{type: :thumbnail_offset, name: "ThumbnailOffset"},
    <<0x02, 0x02>> => %{type: :thumbnail_length, name: "ThumbnailLength"},
    <<0x02, 0x13>> => %{type: :ycbcr_positioning, name: "YcbcrPositioning"},
    <<0x10, 0x00>> => %{type: :quality, name: "Quality"},
    <<0x10, 0x01>> => %{type: :sharpness, name: "Sharpness"},
    <<0x10, 0x02>> => %{type: :white_balance, name: "WhiteBalance"},
    <<0x10, 0x10>> => %{type: :fuji_flash_mode, name: "FujiFlashMode"},
    <<0x10, 0x11>> => %{type: :flash_exposure_comp, name: "FlashExposureComp"},
    <<0x10, 0x20>> => %{type: :macro, name: "Macro"},
    <<0x10, 0x21>> => %{type: :focus_mode, name: "FocusMode"},
    <<0x10, 0x30>> => %{type: :slow_sync, name: "SlowSync"},
    <<0x10, 0x31>> => %{type: :picture_mode, name: "PictureMode"},
    <<0x11, 0x00>> => %{type: :auto_bracketing, name: "AutoBracketing"},
    <<0x12, 0x00>> => %{type: :tag_0x1200, name: "Tag0x1200"},
    <<0x13, 0x00>> => %{type: :blur_warning, name: "BlurWarning"},
    <<0x13, 0x01>> => %{type: :focus_warning, name: "FocusWarning"},
    <<0x13, 0x02>> => %{type: :exposure_warning, name: "ExposureWarning"},
    <<0x87, 0x69>> => %{type: :exif_offset, name: "ExifOffset"},
    <<0x88, 0x25>> => %{type: :gps_info, name: "GPSInfo"},
    <<0x82, 0x98>> => %{type: :copyright, name: "Copyright"},
    <<0x82, 0x9a>> => %{type: :exposure_time, name: "ExposureTime"},
    <<0x82, 0x9d>> => %{type: :f_number, name: "FNumber"},
    <<0x88, 0x22>> => %{type: :exposure_program, name: "ExposureProgram"},
    <<0x88, 0x27>> => %{type: :iso, name: "Iso"},
    <<0x90, 0x00>> => %{type: :exif_version, name: "ExifVersion"},
    <<0x90, 0x03>> => %{type: :date_time_original, name: "DateTimeOriginal"},
    <<0x90, 0x04>> => %{type: :create_date, name: "CreateDate"},
    <<0x90, 0x10>> => %{type: :offset_time, name: "OffsetTime"},
    <<0x90, 0x11>> => %{type: :offset_time_original, name: "OffsetTimeOriginal"},
    <<0x91, 0x01>> => %{type: :components_configuration, name: "ComponentsConfiguration"},
    <<0x91, 0x02>> => %{type: :compressed_bits_per_pixel, name: "CompressedBitsPerPixel"},
    <<0x92, 0x01>> => %{type: :shutter_speed_value, name: "ShutterSpeedValue"},
    <<0x92, 0x02>> => %{type: :aperture_value, name: "ApertureValue"},
    <<0x92, 0x03>> => %{type: :brightness_value, name: "BrightnessValue"},
    <<0x92, 0x04>> => %{type: :exposure_compensation, name: "ExposureCompensation"},
    <<0x92, 0x05>> => %{type: :max_aperture_value, name: "MaxApertureValue"},
    <<0x92, 0x07>> => %{type: :metering_mode, name: "MeteringMode"},
    <<0x92, 0x09>> => %{type: :flash, name: "Flash"},
    <<0x92, 0x0a>> => %{type: :focal_length, name: "FocalLength"},
    <<0x92, 0x7c>> => %{type: :maker_notes, name: "MakerNotes"},
    <<0xa0, 0x00>> => %{type: :flashpix_version, name: "FlashpixVersion"},
    <<0xa0, 0x01>> => %{type: :color_space, name: "ColorSpace"},
    <<0xa0, 0x02>> => %{type: :exif_image_width, name: "ExifImageWidth"},
    <<0xa0, 0x03>> => %{type: :exif_image_height, name: "ExifImageHeight"},
    <<0xa0, 0x05>> => %{type: :interop_offset, name: "InteropOffset"},
    <<0xa2, 0x0e>> => %{type: :focal_plane_x_resolution, name: "FocalPlaneXResolution"},
    <<0xa2, 0x0f>> => %{type: :focal_plane_y_resolution, name: "FocalPlaneYResolution"},
    <<0xa2, 0x10>> => %{type: :focal_plane_resolution_unit, name: "FocalPlaneResolutionUnit"},
    <<0xa2, 0x17>> => %{type: :sensing_method, name: "SensingMethod"},
    <<0xa3, 0x00>> => %{type: :file_source, name: "FileSource"},
    <<0xa3, 0x01>> => %{type: :scene_type, name: "SceneType"},
    <<0xa4, 0x02>> => %{type: :exposure_mode, name: "ExposureMode"},
    <<0xa4, 0x03>> => %{type: :white_balance, name: "WhiteBalance"},
    <<0xa4, 0x04>> => %{type: :digital_zoom_ratio, name: "DigitalZoomRatio"},
    <<0xa4, 0x05>> => %{type: :focal_length_in_35mm_format, name: "FocalLengthIn35mmFormat"},
    <<0xa4, 0x06>> => %{type: :scene_capture_type, name: "SceneCaptureType"},
    <<0xa4, 0x20>> => %{type: :image_unique_id, name: "ImageUniqueId"}
  }

  def new(%OffsetBuffer{} = buffer) do
    {tag, buffer} = OffsetBuffer.consume(buffer, 2)
    big_endian_tag = Binary.big_endian(tag)
    entry = @entry[big_endian_tag]
    if !entry do
      position = OffsetBuffer.tell(buffer) - 2
      offset = buffer.offset
      raise "Unknown tag #{inspect(tag, [base: :hex])} found at 0x#{Integer.to_string(position, 16)}, offset 0x#{Integer.to_string(offset, 16)}"
    end
    entry_type = entry.type
    {format, buffer} = OffsetBuffer.consume(buffer, 2)
    big_endian_format = Binary.big_endian(format)
    format_type = @format[big_endian_format].type
    value = value(entry_type, big_endian_format, buffer)
    buffer = OffsetBuffer.skip(buffer, 8)
    {%__MODULE__{type: entry_type, format: format_type, value: value}, buffer}
  end

  def format_name(%__MODULE__{format: format}) do
    @format_name[format]
  end

  defp value(
    _type,
    @format_string,
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<length_binary::binary-size(4), offset_binary::binary-size(4), _rest::binary>>
      }
    } = buffer
  ) do
    string_length = Binary.to_integer(length_binary)
    string_offset = Binary.to_integer(offset_binary)
    OffsetBuffer.random(buffer, string_offset, string_length - 1)
  end

  defp value(
    _type,
    @format_int16u,
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<_size::binary-size(4), value_binary::binary-size(4), _rest::binary>>
      }
    }
  ) do
    Binary.to_integer(value_binary)
  end

  defp value(
    _type,
    @format_int32u,
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<_size::binary-size(4), value_binary::binary-size(4), _rest::binary>>
      }
    }
  ) do
    Binary.to_integer(value_binary)
  end

  defp value(
    _type,
    @format_rational_64u,
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<count_binary::binary-size(4), offset_binary::binary-size(4), _rest::binary>>
      }
    } = buffer
  ) do
    rational_count = Binary.to_integer(count_binary)
    value_offset = Binary.to_integer(offset_binary)
    OffsetBuffer.random(buffer, value_offset, rational_count * 8)
    |> Binary.to_rational()
  end

  defp value(
    _type,
    @format_rational_64s,
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<_size::binary-size(4), offset_binary::binary-size(4), _rest::binary>>
      }
    } = buffer
  ) do
    value_offset = Binary.to_integer(offset_binary)
    OffsetBuffer.random(buffer, value_offset, 8)
    |> Binary.to_signed_rational()
  end

  defp value(
    :maker_notes,
    @format_inline_string,
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<_size_binary::binary-size(4), offset_binary::binary-size(4), _rest::binary>>
      }
    } = buffer
  ) do
    ifd_offset = Binary.to_integer(offset_binary)
    position = OffsetBuffer.tell(buffer)
    buffer = OffsetBuffer.seek(buffer, ifd_offset)
    {header, buffer} = OffsetBuffer.consume(buffer, 12)
    # Temporarily set process-local byte order
    file_byte_order = Binary.byte_order()
    Binary.set_byte_order(:little)
    {ifd, buffer} = IFD.read(buffer)
    Binary.set_byte_order(file_byte_order)
    _buffer = OffsetBuffer.seek(buffer, position)
    %MakerNotes{header: header, ifd: ifd}
  end

  defp value(
    _type,
    @format_inline_string,
    %OffsetBuffer{
      buffer: %Buffer{
        data: <<size_binary::binary-size(4), value_binary::binary-size(4), _rest::binary>>
      }
    } = buffer
  ) do
    size = Binary.to_integer(size_binary)
    if size <= 4 do
      <<value::binary-size(size), _rest::binary>> = value_binary
      value
    else
      offset = Binary.to_integer(value_binary)
      OffsetBuffer.random(buffer, offset, size - 1)
    end
  end
end
