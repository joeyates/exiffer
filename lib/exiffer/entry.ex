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

  @enforce_keys ~w(type value)a
  defstruct ~w(type value)a

  # Binaries are big endian

  @format_string <<0x00, 0x02>>
  @format_int16u <<0x00, 0x03>>
  @format_int32u <<0x00, 0x04>>
  @format_rational_64u <<0x00, 0x05>>
  @format_raw_bytes <<0x00, 0x07>>
  @format_rational_64s <<0x00, 0x0a>>

  @format_type %{
    @format_string => :string,
    @format_int16u => :int16u,
    @format_int32u => :int32u,
    @format_rational_64u => :rational_64u,
    @format_raw_bytes => :raw_bytes,
    @format_rational_64s => :rational_64s
  }

  @format %{
    string: %{magic: @format_string, type: :string, name: "String"},
    int16u: %{magic: @format_int16u, type: :int16u, name: "16-bit integer"},
    int32u: %{magic: @format_int32u, type: :int32u, name: "32-bit integer"},
    rational_64u: %{magic: @format_rational_64u, type: :rational_64u, name: "64-bit rational"},
    raw_bytes: %{magic: @format_raw_bytes, type: :raw_bytes, name: "Inline String"},
    rational_64s: %{magic: @format_rational_64s, type: :rational_64s, name: "64-bit signed rational"}
  }

  # Map format magic to format type
  @format_type Enum.into(@format, %{}, fn {type, %{magic: magic}} -> {magic, type} end)

  @doc "Formats whose data fits in 4 bytes"

  # Map entry type to entry info
  # TODO: sort by type
  @entry %{
    version: %{type: :version, magic: <<0x00, 0x00>>, format: @format_raw_bytes, name: "Version"},
    gps_latitude_ref: %{type: :gps_latitude_ref, magic: <<0x00, 0x01>>, format: @format_string, name: "GPSLatitudeRef"},
    gps_latitude: %{type: :gps_latitude, magic: <<0x00, 0x02>>, format: @format_rational_64u, name: "GPSLatitude"},
    gps_longitude_ref: %{type: :gps_longitude_ref, magic: <<0x00, 0x03>>, format: @format_string, name: "GPSLongitudeRef"},
    gps_longitude: %{type: :gps_longitude, magic: <<0x00, 0x04>>, format: @format_rational_64u, name: "GPSLongitude"},
    gps_altitude_ref: %{type: :gps_altitude_ref, magic: <<0x00, 0x05>>, format: @format_int16u, name: "GPSAltitudeRef"},
    gps_altitude: %{type: :gps_altitude, magic: <<0x00, 0x06>>, format: @format_rational_64u, name: "GPSAltitude"},
    image_width: %{type: :image_width, magic: <<0x01, 0x00>>, format: @format_int32u, name: "ImageWidth"},
    image_height: %{type: :image_height, magic: <<0x01, 0x01>>, format: @format_int32u, name: "ImageHeight"},
    compression: %{type: :compression, magic: <<0x01, 0x03>>, format: @format_int16u, name: "Compression"},
    make: %{type: :make, magic: <<0x01, 0x0f>>, format: @format_string, name: "Make"},
    model: %{type: :model, magic: <<0x01, 0x10>>, format: @format_string, name: "Model"},
    orientation: %{type: :orientation, magic: <<0x01, 0x12>>, format: @format_int16u, name: "Orientation"},
    x_resolution: %{type: :x_resolution, magic: <<0x01, 0x1a>>, format: @format_rational_64u, name: "XResolution"},
    y_resolution: %{type: :y_resolution, magic: <<0x01, 0x1b>>, format: @format_rational_64u, name: "YResolution"},
    resolution_unit: %{type: :resolution_unit, magic: <<0x01, 0x28>>, format: @format_int16u, name: "ResolutionUnit"},
    software: %{type: :software, magic: <<0x01, 0x31>>, format: @format_string, name: "Software"},
    modification_date: %{type: :modification_date, magic: <<0x01, 0x32>>, format: @format_string, name: "ModificationDate"},
    thumbnail_offset: %{type: :thumbnail_offset, magic: <<0x02, 0x01>>, format: @format_int32u, name: "ThumbnailOffset"},
    thumbnail_length: %{type: :thumbnail_length, magic: <<0x02, 0x02>>, format: @format_int32u, name: "ThumbnailLength"},
    ycbcr_positioning: %{type: :ycbcr_positioning, magic: <<0x02, 0x13>>, format: @format_int16u, name: "YcbcrPositioning"},
    quality: %{type: :quality, magic: <<0x10, 0x00>>, format: @format_string, name: "Quality"},
    sharpness: %{type: :sharpness, magic: <<0x10, 0x01>>, format: @format_int16u, name: "Sharpness"},
    fuji_white_balance: %{type: :fuji_white_balance, magic: <<0x10, 0x02>>, format: @format_int16u, name: "FUJI WhiteBalance"},
    fuji_flash_mode: %{type: :fuji_flash_mode, magic: <<0x10, 0x10>>, format: @format_int16u, name: "FujiFlashMode"},
    flash_exposure_comp: %{type: :flash_exposure_comp, magic: <<0x10, 0x11>>, format: @format_rational_64u, name: "FlashExposureComp"},
    macro: %{type: :macro, magic: <<0x10, 0x20>>, format: @format_int16u, name: "Macro"},
    focus_mode: %{type: :focus_mode, magic: <<0x10, 0x21>>, format: @format_int16u, name: "FocusMode"},
    slow_sync: %{type: :slow_sync, magic: <<0x10, 0x30>>, format: @format_int16u, name: "SlowSync"},
    picture_mode: %{type: :picture_mode, magic: <<0x10, 0x31>>, format: @format_int16u, name: "PictureMode"},
    auto_bracketing: %{type: :auto_bracketing, magic: <<0x11, 0x00>>, format: @format_int16u, name: "AutoBracketing"},
    tag_0x1200: %{type: :tag_0x1200, magic: <<0x12, 0x00>>, format: @format_int16u, name: "Tag0x1200"},
    blur_warning: %{type: :blur_warning, magic: <<0x13, 0x00>>, format: @format_int16u, name: "BlurWarning"},
    focus_warning: %{type: :focus_warning, magic: <<0x13, 0x01>>, format: @format_int16u, name: "FocusWarning"},
    exposure_warning: %{type: :exposure_warning, magic: <<0x13, 0x02>>, format: @format_int16u, name: "ExposureWarning"},
    exif_offset: %{type: :exif_offset, magic: <<0x87, 0x69>>, format: @format_int32u, name: "ExifOffset"},
    gps_info: %{type: :gps_info, magic: <<0x88, 0x25>>, format: @format_int32u, name: "GPSInfo"},
    copyright: %{type: :copyright, magic: <<0x82, 0x98>>, format: @format_string, name: "Copyright"},
    exposure_time: %{type: :exposure_time, magic: <<0x82, 0x9a>>, format: @format_rational_64u, name: "ExposureTime"},
    f_number: %{type: :f_number, magic: <<0x82, 0x9d>>, format: @format_rational_64u, name: "FNumber"},
    exposure_program: %{type: :exposure_program, magic: <<0x88, 0x22>>, format: @format_int16u, name: "ExposureProgram"},
    iso: %{type: :iso, magic: <<0x88, 0x27>>, format: @format_int16u, name: "Iso"},
    exif_version: %{type: :exif_version, magic: <<0x90, 0x00>>, format: @format_raw_bytes, name: "ExifVersion"},
    date_time_original: %{type: :date_time_original, magic: <<0x90, 0x03>>, format: @format_string, name: "DateTimeOriginal"},
    create_date: %{type: :create_date, magic: <<0x90, 0x04>>, format: @format_string, name: "CreateDate"},
    offset_time: %{type: :offset_time, magic: <<0x90, 0x10>>, format: @format_string, name: "OffsetTime"},
    offset_time_original: %{type: :offset_time_original, magic: <<0x90, 0x11>>, format: @format_string, name: "OffsetTimeOriginal"},
    components_configuration: %{type: :components_configuration, magic: <<0x91, 0x01>>, format: @format_raw_bytes, name: "ComponentsConfiguration"},
    compressed_bits_per_pixel: %{type: :compressed_bits_per_pixel, magic: <<0x91, 0x02>>, format: @format_rational_64u, name: "CompressedBitsPerPixel"},
    shutter_speed_value: %{type: :shutter_speed_value, magic: <<0x92, 0x01>>, format: @format_rational_64u, name: "ShutterSpeedValue"},
    aperture_value: %{type: :aperture_value, magic: <<0x92, 0x02>>, format: @format_rational_64u, name: "ApertureValue"},
    brightness_value: %{type: :brightness_value, magic: <<0x92, 0x03>>, format: @format_rational_64s, name: "BrightnessValue"},
    exposure_compensation: %{type: :exposure_compensation, magic: <<0x92, 0x04>>, format: @format_rational_64s, name: "ExposureCompensation"},
    max_aperture_value: %{type: :max_aperture_value, magic: <<0x92, 0x05>>, format: @format_rational_64u, name: "MaxApertureValue"},
    metering_mode: %{type: :metering_mode, magic: <<0x92, 0x07>>, format: @format_int16u, name: "MeteringMode"},
    flash: %{type: :flash, magic: <<0x92, 0x09>>, format: @format_int16u, name: "Flash"},
    focal_length: %{type: :focal_length, magic: <<0x92, 0x0a>>, format: @format_rational_64u, name: "FocalLength"},
    maker_notes: %{type: :maker_notes, magic: <<0x92, 0x7c>>, format: @format_raw_bytes, name: "MakerNotes"},
    flashpix_version: %{type: :flashpix_version, magic: <<0xa0, 0x00>>, format: @format_raw_bytes, name: "FlashpixVersion"},
    color_space: %{type: :color_space, magic: <<0xa0, 0x01>>, format: @format_int16u, name: "ColorSpace"},
    exif_image_width: %{type: :exif_image_width, magic: <<0xa0, 0x02>>, format: @format_int32u, name: "ExifImageWidth"},
    exif_image_height: %{type: :exif_image_height, magic: <<0xa0, 0x03>>, format: @format_int32u, name: "ExifImageHeight"},
    interop_offset: %{type: :interop_offset, magic: <<0xa0, 0x05>>, format: @format_int32u, name: "InteropOffset"},
    focal_plane_x_resolution: %{type: :focal_plane_x_resolution, magic: <<0xa2, 0x0e>>, format: @format_rational_64u, name: "FocalPlaneXResolution"},
    focal_plane_y_resolution: %{type: :focal_plane_y_resolution, magic: <<0xa2, 0x0f>>, format: @format_rational_64u, name: "FocalPlaneYResolution"},
    focal_plane_resolution_unit: %{type: :focal_plane_resolution_unit, magic: <<0xa2, 0x10>>, format: @format_int16u, name: "FocalPlaneResolutionUnit"},
    sensing_method: %{type: :sensing_method, magic: <<0xa2, 0x17>>, format: @format_int16u, name: "SensingMethod"},
    file_source: %{type: :file_source, magic: <<0xa3, 0x00>>, format: @format_raw_bytes, name: "FileSource"},
    scene_type: %{type: :scene_type, magic: <<0xa3, 0x01>>, format: @format_raw_bytes, name: "SceneType"},
    exposure_mode: %{type: :exposure_mode, magic: <<0xa4, 0x02>>, format: @format_int16u, name: "ExposureMode"},
    exif_white_balance: %{type: :exif_white_balance, magic: <<0xa4, 0x03>>, format: @format_int16u, name: "EXIF WhiteBalance"},
    digital_zoom_ratio: %{type: :digital_zoom_ratio, magic: <<0xa4, 0x04>>, format: @format_rational_64u, name: "DigitalZoomRatio"},
    focal_length_in_35mm_format: %{type: :focal_length_in_35mm_format, magic: <<0xa4, 0x05>>, format: @format_int16u, name: "FocalLengthIn35mmFormat"},
    scene_capture_type: %{type: :scene_capture_type, magic: <<0xa4, 0x06>>, format: @format_int16u, name: "SceneCaptureType"},
    image_unique_id: %{type: :image_unique_id, magic: <<0xa4, 0x20>>, format: @format_string, name: "ImageUniqueId"}
  }

  # Map magic numbers to entry types
  @entry_type Enum.into(@entry, %{}, fn {type, %{magic: magic}} -> {magic, type} end)

  def new(%OffsetBuffer{} = buffer) do
    {magic, buffer} = OffsetBuffer.consume(buffer, 2)
    big_endian_magic = Binary.big_endian(magic)
    entry_type = @entry_type[big_endian_magic]
    if !entry_type do
      position = OffsetBuffer.tell(buffer) - 2
      offset = buffer.offset
      raise "Unknown magic #{inspect(magic, [base: :hex])} found at 0x#{Integer.to_string(position, 16)}, offset 0x#{Integer.to_string(offset, 16)}"
    end
    info = @entry[entry_type]
    {format_magic, buffer} = OffsetBuffer.consume(buffer, 2)
    big_endian_format_magic = Binary.big_endian(format_magic)
    format_type = @format_type[big_endian_format_magic]
    if info.format != big_endian_format_magic do
      position = OffsetBuffer.tell(buffer) - 4
      offset = buffer.offset
      expected = @format_type[info.format]
      raise "#{info.name} Entry format #{format_type} differs from expected #{expected} found at 0x#{Integer.to_string(position, 16)}, offset 0x#{Integer.to_string(offset, 16)}"
    end
    value = value(entry_type, big_endian_format_magic, buffer)
    buffer = OffsetBuffer.skip(buffer, 8)
    {%__MODULE__{type: entry_type, value: value}, buffer}
  end

  def format_name(%__MODULE__{type: type}) do
    format = @entry[type].format
    @format_type[format]
  end

  @doc """
  Returns a two-ple {ifd_entry, ifd_extra_data},
  where ifd_extra_data is `<<>>` if there is none to be added.
  """
  def binary(%__MODULE__{type: type} = entry, end_of_block) when type in [:exif_offset, :gps_info] do
    info = @entry[entry.type]
    magic_binary = Binary.big_endian_to_current(info.magic)
    format_binary = Binary.big_endian_to_current(info.format)
    size_binary = Binary.int32u_to_current(1)
    value = Binary.int32u_to_current(end_of_block)
    header = <<magic_binary::binary, format_binary::binary, size_binary::binary, value::binary>>
    extra = IFD.binary(entry.value, end_of_block)
    {header, extra}
  end

  def binary(%__MODULE__{} = entry, end_of_block) do
    info = @entry[entry.type]
    magic_binary = Binary.big_endian_to_current(info.magic)
    format_binary = Binary.big_endian_to_current(info.format)
    {size, value, extra} = data(entry, info.format, end_of_block)
    size_binary = Binary.int32u_to_current(size)
    header = <<magic_binary::binary, format_binary::binary, size_binary::binary, value::binary>>
    {header, extra}
  end

  defp data(%__MODULE__{type: :maker_notes, value: value}, _format, end_of_block) do
    file_byte_order = Binary.byte_order()
    Binary.set_byte_order(:little)
    ifd_end = byte_size(value.header)
    binary = IFD.binary(value.ifd, ifd_end)
    Binary.set_byte_order(file_byte_order)
    extra = <<value.header::binary, binary::binary>>
    size = byte_size(extra)
    value = Binary.int32u_to_current(end_of_block)
    {size, value, extra}
  end

  defp data(%__MODULE__{type: :thumbnail_offset} = entry, _format, end_of_block) do
    value = Binary.int32u_to_current(end_of_block)
    extra = entry.value
    {1, value, extra}
  end

  defp data(%__MODULE__{} = entry, @format_int16u, _end_of_block) do
    value = <<Binary.int16u_to_current(entry.value)::binary, 0x00, 0x00>>
    {1, value, <<>>}
  end

  defp data(%__MODULE__{} = entry, @format_int32u, _end_of_block) do
    value = Binary.int32u_to_current(entry.value)
    {1, value, <<>>}
  end

  defp data(%__MODULE__{} = entry, format, end_of_block) when format in [@format_string, @format_raw_bytes] do
    size = byte_size(entry.value)
    if size <= 4 do
      pad_count = 4 - size
      <<padding::binary-size(pad_count), _rest::binary>> = <<0, 0, 0, 0>>
      {size, <<entry.value::binary, padding::binary>>, <<>>}
    else
      # Always add a final NULL after strings added after the block
      size = size + 1
      value = <<entry.value::binary, 0x00>>
      extra = if rem(size, 2) == 1 do
        # pad to make byte count even
        <<value::binary, 0x00>>
      else
        value
      end
      {size, Binary.int32u_to_current(end_of_block), extra}
    end
  end

  defp data(%__MODULE__{} = entry, @format_rational_64u, end_of_block) do
    value = Binary.int32u_to_current(end_of_block)
    extra = Binary.rational_to_current(entry.value)
    size = div(byte_size(extra), 8)
    {size, value, extra}
  end

  defp data(%__MODULE__{} = entry, @format_rational_64s, end_of_block) do
    extra = Binary.signed_rational_to_current(entry.value)
    size = div(byte_size(extra), 8)
    value = Binary.int32u_to_current(end_of_block)
    {size, value, extra}
  end

  defp read_ifd(%OffsetBuffer{} = buffer, offset) do
    position = OffsetBuffer.tell(buffer)
    buffer = OffsetBuffer.seek(buffer, offset)
    {ifd, buffer} = IFD.read(buffer)
    _buffer = OffsetBuffer.seek(buffer, position)
    ifd
  end

  defp value(type, @format_int32u, %OffsetBuffer{} = buffer) when type in @ifd_entries do
    <<_size_binary::binary-size(4), offset_binary::binary-size(4), _rest::binary>> = buffer.buffer.data
    offset = Binary.to_integer(offset_binary)
    read_ifd(buffer, offset)
  end

  defp value(:maker_notes, @format_raw_bytes, %OffsetBuffer{} = buffer) do
    <<_size_binary::binary-size(4), offset_binary::binary-size(4), _rest::binary>> = buffer.buffer.data
    ifd_offset = Binary.to_integer(offset_binary)
    Logger.info "maker_notes, ifd_offset: #{inspect(ifd_offset, [base: :hex, pretty: true, width: 0])}"
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

  defp value(_type, format, %OffsetBuffer{} = buffer) when format in [@format_string, @format_raw_bytes] do
    <<length_binary::binary-size(4), value_binary::binary-size(4), _rest::binary>> = buffer.buffer.data
    string_length = Binary.to_integer(length_binary)
    if string_length <= 4 do
      <<value::binary-size(string_length), _rest::binary>> = value_binary
      value
    else
      string_offset = Binary.to_integer(value_binary)
      OffsetBuffer.random(buffer, string_offset, string_length - 1)
    end
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
end
