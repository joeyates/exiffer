defmodule Exiffer.Entry do
  @moduledoc """
  Documentation for `Exiffer.Entry`.
  """

  alias Exiffer.Binary
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
  @entry_info %{
    version: %{type: :version, magic: <<0x00, 0x00>>, formats: [:raw_bytes], name: "Version", label: "Version"},
    gps_latitude_ref: %{type: :gps_latitude_ref, magic: <<0x00, 0x01>>, formats: [:string], name: "GPSLatitudeRef", label: "GPS Latitude Ref"},
    gps_latitude: %{type: :gps_latitude, magic: <<0x00, 0x02>>, formats: [:rational_64u], name: "GPSLatitude", label: "GPS Latitude"},
    gps_longitude_ref: %{type: :gps_longitude_ref, magic: <<0x00, 0x03>>, formats: [:string], name: "GPSLongitudeRef", label: "GPS Longitude Ref"},
    gps_longitude: %{type: :gps_longitude, magic: <<0x00, 0x04>>, formats: [:rational_64u], name: "GPSLongitude", label: "GPS Longitude"},
    gps_altitude_ref: %{type: :gps_altitude_ref, magic: <<0x00, 0x05>>, formats: [:int16u], name: "GPSAltitudeRef", label: "GPS Altitude Ref"},
    gps_altitude: %{type: :gps_altitude, magic: <<0x00, 0x06>>, formats: [:rational_64u], name: "GPSAltitude", label: "GPS Altitude"},
    image_width: %{type: :image_width, magic: <<0x01, 0x00>>, formats: [:int32u], name: "ImageWidth", label: "Image Width"},
    image_height: %{type: :image_height, magic: <<0x01, 0x01>>, formats: [:int32u], name: "ImageHeight", label: "Image Height"},
    compression: %{type: :compression, magic: <<0x01, 0x03>>, formats: [:int16u], name: "Compression", label: "Compression"},
    make: %{type: :make, magic: <<0x01, 0x0f>>, formats: [:string], name: "Make", label: "Make"},
    model: %{type: :model, magic: <<0x01, 0x10>>, formats: [:string], name: "Model", label: "Model"},
    orientation: %{type: :orientation, magic: <<0x01, 0x12>>, formats: [:int16u], name: "Orientation", label: "Orientation"},
    x_resolution: %{type: :x_resolution, magic: <<0x01, 0x1a>>, formats: [:rational_64u], name: "XResolution", label: "X Resolution"},
    y_resolution: %{type: :y_resolution, magic: <<0x01, 0x1b>>, formats: [:rational_64u], name: "YResolution", label: "Y Resolution"},
    resolution_unit: %{type: :resolution_unit, magic: <<0x01, 0x28>>, formats: [:int16u], name: "ResolutionUnit", label: "Resolution Unit"},
    software: %{type: :software, magic: <<0x01, 0x31>>, formats: [:string], name: "Software", label: "Software"},
    modification_date: %{type: :modification_date, magic: <<0x01, 0x32>>, formats: [:string], name: "ModificationDate", label: "Modification Date"},
    thumbnail_offset: %{type: :thumbnail_offset, magic: <<0x02, 0x01>>, formats: [:int32u], name: "ThumbnailOffset", label: "Thumbnail Offset"},
    thumbnail_length: %{type: :thumbnail_length, magic: <<0x02, 0x02>>, formats: [:int32u], name: "ThumbnailLength", label: "Thumbnail Length"},
    ycbcr_positioning: %{type: :ycbcr_positioning, magic: <<0x02, 0x13>>, formats: [:int16u], name: "YcbcrPositioning", label: "Ycbcr Positioning"},
    quality: %{type: :quality, magic: <<0x10, 0x00>>, formats: [:string], name: "Quality", label: "Quality"},
    sharpness: %{type: :sharpness, magic: <<0x10, 0x01>>, formats: [:int16u], name: "Sharpness", label: "Sharpness"},
    fuji_white_balance: %{type: :fuji_white_balance, magic: <<0x10, 0x02>>, formats: [:int16u], name: "FUJI WhiteBalance", label: "FUJI White Balance"},
    fuji_flash_mode: %{type: :fuji_flash_mode, magic: <<0x10, 0x10>>, formats: [:int16u], name: "FujiFlashMode", label: "Fuji Flash Mode"},
    # FlashExposureComp seems to be flash strength
    flash_exposure_comp: %{type: :flash_exposure_comp, magic: <<0x10, 0x11>>, formats: [:rational_64s], name: "FlashExposureComp", label: "Flash Exposure Comp"},
    macro: %{type: :macro, magic: <<0x10, 0x20>>, formats: [:int16u], name: "Macro", label: "Macro"},
    focus_mode: %{type: :focus_mode, magic: <<0x10, 0x21>>, formats: [:int16u], name: "FocusMode", label: "Focus Mode"},
    slow_sync: %{type: :slow_sync, magic: <<0x10, 0x30>>, formats: [:int16u], name: "SlowSync", label: "Slow Sync"},
    picture_mode: %{type: :picture_mode, magic: <<0x10, 0x31>>, formats: [:int16u], name: "PictureMode", label: "Picture Mode"},
    auto_bracketing: %{type: :auto_bracketing, magic: <<0x11, 0x00>>, formats: [:int16u], name: "AutoBracketing", label: "Auto Bracketing"},
    tag_0x1200: %{type: :tag_0x1200, magic: <<0x12, 0x00>>, formats: [:int16u], name: "Tag0x1200", label: "Tag0x1200"},
    blur_warning: %{type: :blur_warning, magic: <<0x13, 0x00>>, formats: [:int16u], name: "BlurWarning", label: "Blur Warning"},
    focus_warning: %{type: :focus_warning, magic: <<0x13, 0x01>>, formats: [:int16u], name: "FocusWarning", label: "Focus Warning"},
    exposure_warning: %{type: :exposure_warning, magic: <<0x13, 0x02>>, formats: [:int16u], name: "ExposureWarning", label: "Exposure Warning"},
    exif_offset: %{type: :exif_offset, magic: <<0x87, 0x69>>, formats: [:int32u], name: "ExifOffset", label: "Exif Offset"},
    gps_info: %{type: :gps_info, magic: <<0x88, 0x25>>, formats: [:int32u], name: "GPSInfo", label: "GPSInfo"},
    copyright: %{type: :copyright, magic: <<0x82, 0x98>>, formats: [:string], name: "Copyright", label: "Copyright"},
    exposure_time: %{type: :exposure_time, magic: <<0x82, 0x9a>>, formats: [:rational_64u], name: "ExposureTime", label: "Exposure Time"},
    f_number: %{type: :f_number, magic: <<0x82, 0x9d>>, formats: [:rational_64u], name: "FNumber", label: "F Number"},
    exposure_program: %{type: :exposure_program, magic: <<0x88, 0x22>>, formats: [:int16u], name: "ExposureProgram", label: "Exposure Program"},
    iso: %{type: :iso, magic: <<0x88, 0x27>>, formats: [:int16u], name: "Iso", label: "Iso"},
    exif_version: %{type: :exif_version, magic: <<0x90, 0x00>>, formats: [:raw_bytes], name: "ExifVersion", label: "Exif Version"},
    date_time_original: %{type: :date_time_original, magic: <<0x90, 0x03>>, formats: [:string], name: "DateTimeOriginal", label: "Date Time Original"},
    create_date: %{type: :create_date, magic: <<0x90, 0x04>>, formats: [:string], name: "CreateDate", label: "Create Date"},
    offset_time: %{type: :offset_time, magic: <<0x90, 0x10>>, formats: [:string], name: "OffsetTime", label: "Offset Time"},
    offset_time_original: %{type: :offset_time_original, magic: <<0x90, 0x11>>, formats: [:string], name: "OffsetTimeOriginal", label: "Offset Time Original"},
    components_configuration: %{type: :components_configuration, magic: <<0x91, 0x01>>, formats: [:raw_bytes], name: "ComponentsConfiguration", label: "Components Configuration"},
    compressed_bits_per_pixel: %{type: :compressed_bits_per_pixel, magic: <<0x91, 0x02>>, formats: [:rational_64u], name: "CompressedBitsPerPixel", label: "Compressed Bits Per Pixel"},
    shutter_speed_value: %{type: :shutter_speed_value, magic: <<0x92, 0x01>>, formats: [:rational_64u, :rational_64s], name: "ShutterSpeedValue", label: "Shutter Speed Value"},
    aperture_value: %{type: :aperture_value, magic: <<0x92, 0x02>>, formats: [:rational_64u], name: "ApertureValue", label: "Aperture Value"},
    brightness_value: %{type: :brightness_value, magic: <<0x92, 0x03>>, formats: [:rational_64s], name: "BrightnessValue", label: "Brightness Value"},
    exposure_compensation: %{type: :exposure_compensation, magic: <<0x92, 0x04>>, formats: [:rational_64s], name: "ExposureCompensation", label: "Exposure Compensation"},
    max_aperture_value: %{type: :max_aperture_value, magic: <<0x92, 0x05>>, formats: [:rational_64u], name: "MaxApertureValue", label: "Max Aperture Value"},
    metering_mode: %{type: :metering_mode, magic: <<0x92, 0x07>>, formats: [:int16u], name: "MeteringMode", label: "Metering Mode"},
    flash: %{type: :flash, magic: <<0x92, 0x09>>, formats: [:int16u], name: "Flash", label: "Flash"},
    focal_length: %{type: :focal_length, magic: <<0x92, 0x0a>>, formats: [:rational_64u], name: "FocalLength", label: "Focal Length"},
    maker_notes: %{type: :maker_notes, magic: <<0x92, 0x7c>>, formats: [:raw_bytes], name: "MakerNotes", label: "Maker Notes"},
    flashpix_version: %{type: :flashpix_version, magic: <<0xa0, 0x00>>, formats: [:raw_bytes], name: "FlashpixVersion", label: "Flashpix Version"},
    color_space: %{type: :color_space, magic: <<0xa0, 0x01>>, formats: [:int16u], name: "ColorSpace", label: "Color Space"},
    exif_image_width: %{type: :exif_image_width, magic: <<0xa0, 0x02>>, formats: [:int32u], name: "ExifImageWidth", label: "Exif Image Width"},
    exif_image_height: %{type: :exif_image_height, magic: <<0xa0, 0x03>>, formats: [:int32u], name: "ExifImageHeight", label: "Exif Image Height"},
    interop_offset: %{type: :interop_offset, magic: <<0xa0, 0x05>>, formats: [:int32u], name: "InteropOffset", label: "Interop Offset"},
    focal_plane_x_resolution: %{type: :focal_plane_x_resolution, magic: <<0xa2, 0x0e>>, formats: [:rational_64u], name: "FocalPlaneXResolution", label: "Focal Plane X Resolution"},
    focal_plane_y_resolution: %{type: :focal_plane_y_resolution, magic: <<0xa2, 0x0f>>, formats: [:rational_64u], name: "FocalPlaneYResolution", label: "Focal Plane Y Resolution"},
    focal_plane_resolution_unit: %{type: :focal_plane_resolution_unit, magic: <<0xa2, 0x10>>, formats: [:int16u], name: "FocalPlaneResolutionUnit", label: "Focal Plane Resolution Unit"},
    sensing_method: %{type: :sensing_method, magic: <<0xa2, 0x17>>, formats: [:int16u], name: "SensingMethod", label: "Sensing Method"},
    file_source: %{type: :file_source, magic: <<0xa3, 0x00>>, formats: [:raw_bytes], name: "FileSource", label: "File Source"},
    scene_type: %{type: :scene_type, magic: <<0xa3, 0x01>>, formats: [:raw_bytes], name: "SceneType", label: "Scene Type"},
    exposure_mode: %{type: :exposure_mode, magic: <<0xa4, 0x02>>, formats: [:int16u], name: "ExposureMode", label: "Exposure Mode"},
    exif_white_balance: %{type: :exif_white_balance, magic: <<0xa4, 0x03>>, formats: [:int16u], name: "EXIF WhiteBalance", label: "EXIF White Balance"},
    digital_zoom_ratio: %{type: :digital_zoom_ratio, magic: <<0xa4, 0x04>>, formats: [:rational_64u], name: "DigitalZoomRatio", label: "Digital Zoom Ratio"},
    focal_length_in_35mm_format: %{type: :focal_length_in_35mm_format, magic: <<0xa4, 0x05>>, formats: [:int16u], name: "FocalLengthIn35mmFormat", label: "Focal Length In 35mm Format"},
    scene_capture_type: %{type: :scene_capture_type, magic: <<0xa4, 0x06>>, formats: [:int16u], name: "SceneCaptureType", label: "Scene Capture Type"},
    image_unique_id: %{type: :image_unique_id, magic: <<0xa4, 0x20>>, formats: [:string], name: "ImageUniqueId", label: "Image Unique Id"}
  }

  # Interop IFD entries reuse generic entry magic numbers, so we use a specific table for them
  @interop_entry_info %{
    interop_index: %{type: :interop_index, magic: <<0x00, 0x01>>, formats: [:string], name: "InteropIndex", label: "Interop Index"},
    interop_version: %{type: :interop_version, magic: <<0x00, 0x02>>, formats: [:raw_bytes], name: "InteropVersion", label: "Interop Version"}
  }

  @entry_info_map %{
    nil: @entry_info,
    interop: @interop_entry_info
  }

  # Map magic numbers to entry types
  @entry_type Enum.into(@entry_info, %{}, fn {type, %{magic: magic}} -> {magic, type} end)
  @interop_entry_type Enum.into(@interop_entry_info, %{}, fn {type, %{magic: magic}} -> {magic, type} end)

  @entry_type_map %{
    nil: @entry_type,
    interop: @interop_entry_type
  }

  def new(%OffsetBuffer{} = buffer, opts \\ []) do
    override = Keyword.get(opts, :override)
    entry_type_map = @entry_type_map[override]
    {magic, buffer} = OffsetBuffer.consume(buffer, 2)
    big_endian_magic = Binary.big_endian(magic)
    entry_type = entry_type_map[big_endian_magic]
    if !entry_type do
      position = OffsetBuffer.tell(buffer) - 2
      offset = buffer.offset
      raise "Unknown magic #{inspect(magic, [base: :hex])} found at 0x#{Integer.to_string(position, 16)}, offset 0x#{Integer.to_string(offset, 16)}"
    end
    entry_table = @entry_info_map[override]
    info = entry_table[entry_type]
    {format_magic, buffer} = OffsetBuffer.consume(buffer, 2)
    big_endian_format_magic = Binary.big_endian(format_magic)
    format_type = @format_type[big_endian_format_magic]
    if format_type not in info.formats do
      position = OffsetBuffer.tell(buffer) - 4
      offset = buffer.offset
      expected = Enum.map(info.formats, &(@format[&1].name)) |> Enum.join(" or ")
      raise "#{info.name} Entry, found format #{format_type} expected to be #{expected}, at 0x#{Integer.to_string(position, 16)}, offset 0x#{Integer.to_string(offset, 16)}"
    end
    value = value(entry_type, format_type, buffer)
    buffer = OffsetBuffer.skip(buffer, 8)
    {%__MODULE__{type: entry_type, format: format_type, value: value}, buffer}
  end

  def format_name(%__MODULE__{format: format}) do
    @format[format].name
  end

  @doc """
  Returns a two-ple {ifd_entry, ifd_extra_data},
  where ifd_extra_data is `<<>>` if there is none to be added.
  """
  def binary(entry, end_of_block, opts \\ [])

  def binary(%__MODULE__{type: type} = entry, end_of_block, _opts) when type in [:exif_offset, :gps_info, :interop_offset] do
    entry_table = @entry_info_map[nil]
    info = entry_table[entry.type]
    magic_binary = Binary.big_endian_to_current(info.magic)
    format_binary =
      @format[entry.format].magic
      |> Binary.big_endian_to_current()
    size_binary = Binary.int32u_to_current(1)
    value = Binary.int32u_to_current(end_of_block)
    header = <<magic_binary::binary, format_binary::binary, size_binary::binary, value::binary>>
    opts = if type == :interop_offset, do: [override: :interop], else: []
    extra = IFD.binary(entry.value, end_of_block, opts)
    {header, extra}
  end

  def binary(%__MODULE__{} = entry, end_of_block, opts) do
    opts = opts || []
    override = Keyword.get(opts, :override)
    entry_table = @entry_info_map[override]
    info = entry_table[entry.type]
    magic_binary = Binary.big_endian_to_current(info.magic)
    format_binary =
      @format[entry.format].magic
      |> Binary.big_endian_to_current()
    {size, value, extra} = data(entry, end_of_block)
    size_binary = Binary.int32u_to_current(size)
    header = <<magic_binary::binary, format_binary::binary, size_binary::binary, value::binary>>
    {header, extra}
  end

  @doc """
  Returns a two-ple {label, text} suitable for a text representation of the Entry
  """
  def text(entry, opts \\ [])

  def text(%__MODULE__{type: :interop_offset} = entry, _opts) do
    opts = [override: :interop]
    texts =
      entry.value.entries
      |> Enum.flat_map(&(text(&1, opts)))

    [{"Interop", nil} | texts]
  end

  def text(%__MODULE__{type: :exif_offset} = entry, _opts) do
    texts =
      entry.value.entries
      |> Enum.map(&(text(&1)))
      |> Enum.sort_by(&(length(&1)))
      |> List.flatten()

    [{"EXIF", nil} | texts]
  end

  def text(%__MODULE__{type: :thumbnail_offset} = _entry, _opts) do
    []
  end

  def text(%__MODULE__{type: :maker_notes} = entry, _opts) do
    texts =
      entry.value.ifd.entries
      |> Enum.flat_map(&(text(&1)))

    [{"Maker Notes", nil} | texts]
  end

  def text(%__MODULE__{format: :string} = entry, opts) do
    override = Keyword.get(opts, :override)
    entry_table = @entry_info_map[override]
    info = entry_table[entry.type]
    [{info.label, entry.value}]
  end

  def text(%__MODULE__{format: format} = entry, opts) when format in [:int16u, :int32u] do
    override = Keyword.get(opts, :override)
    entry_table = @entry_info_map[override]
    info = entry_table[entry.type]
    [{info.label, Integer.to_string(entry.value)}]
  end

  def text(%__MODULE__{format: :rational_64u} = entry, opts) do
    override = Keyword.get(opts, :override)
    entry_table = @entry_info_map[override]
    info = entry_table[entry.type]
    {numerator, denominator} = entry.value
    value = numerator / denominator
    [{info.label, Float.to_string(value)}]
  end

  def text(%__MODULE__{format: :raw_bytes} = entry, opts) do
    override = Keyword.get(opts, :override)
    entry_table = @entry_info_map[override]
    info = entry_table[entry.type]
    [{info.label, "RAW"}] # TODO
  end

  # TODO: handle negatives
  def text(%__MODULE__{format: :rational_64s} = entry, opts) do
    override = Keyword.get(opts, :override)
    entry_table = @entry_info_map[override]
    info = entry_table[entry.type]
    {numerator, denominator} = entry.value
    value = numerator / denominator
    [{info.label, Float.to_string(value)}]
  end

  defp data(%__MODULE__{type: :maker_notes, value: value}, end_of_block) do
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

  defp data(%__MODULE__{type: :thumbnail_offset} = entry, end_of_block) do
    value = Binary.int32u_to_current(end_of_block)
    extra = entry.value
    {1, value, extra}
  end

  defp data(%__MODULE__{format: :int16u} = entry, _end_of_block) do
    value = <<Binary.int16u_to_current(entry.value)::binary, 0x00, 0x00>>
    {1, value, <<>>}
  end

  defp data(%__MODULE__{format: :int32u} = entry, _end_of_block) do
    value = Binary.int32u_to_current(entry.value)
    {1, value, <<>>}
  end

  defp data(%__MODULE__{format: format} = entry, end_of_block) when format in [:string, :raw_bytes] do
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

  defp data(%__MODULE__{format: :rational_64u} = entry, end_of_block) do
    value = Binary.int32u_to_current(end_of_block)
    extra = Binary.rational_to_current(entry.value)
    size = div(byte_size(extra), 8)
    {size, value, extra}
  end

  defp data(%__MODULE__{format: :rational_64s} = entry, end_of_block) do
    extra = Binary.signed_rational_to_current(entry.value)
    size = div(byte_size(extra), 8)
    value = Binary.int32u_to_current(end_of_block)
    {size, value, extra}
  end

  defp read_ifd(%OffsetBuffer{} = buffer, offset, opts \\ []) do
    position = OffsetBuffer.tell(buffer)
    buffer = OffsetBuffer.seek(buffer, offset)
    {ifd, buffer} = IFD.read(buffer, opts)
    _buffer = OffsetBuffer.seek(buffer, position)
    ifd
  end

  defp value(type, :int32u, %OffsetBuffer{} = buffer) when type == :interop_offset do
    <<_size_binary::binary-size(4), offset_binary::binary-size(4), _rest::binary>> = buffer.buffer.data
    offset = Binary.to_integer(offset_binary)
    read_ifd(buffer, offset, override: :interop)
  end

  defp value(type, :int32u, %OffsetBuffer{} = buffer) when type in [:exif_offset, :gps_info] do
    <<_size_binary::binary-size(4), offset_binary::binary-size(4), _rest::binary>> = buffer.buffer.data
    offset = Binary.to_integer(offset_binary)
    read_ifd(buffer, offset)
  end

  defp value(:maker_notes, :raw_bytes, %OffsetBuffer{} = buffer) do
    position = OffsetBuffer.tell(buffer)
    <<_size_binary::binary-size(4), offset_binary::binary-size(4), _rest::binary>> = buffer.buffer.data
    ifd_offset = Binary.to_integer(offset_binary)
    # Maker notes have their own offset into the file
    notes_offset = buffer.offset + ifd_offset
    notes_buffer =
      OffsetBuffer.new(buffer.buffer, notes_offset)
      |> OffsetBuffer.seek(0)
    {header, notes_buffer} = OffsetBuffer.consume(notes_buffer, 12)
    # Temporarily set process-local byte order
    file_byte_order = Binary.byte_order()
    Binary.set_byte_order(:little)
    {ifd, buffer} = IFD.read(notes_buffer)
    Binary.set_byte_order(file_byte_order)
    _buffer = OffsetBuffer.seek(buffer, position)
    %MakerNotes{header: header, ifd: ifd}
  end

  defp value(_type, format, %OffsetBuffer{} = buffer) when format in [:string, :raw_bytes] do
    <<length_binary::binary-size(4), value_binary::binary-size(4), _rest::binary>> = buffer.buffer.data
    length = Binary.to_integer(length_binary)
    length = if format == :string, do: length - 1, else: length
    if length <= 4 do
      <<value::binary-size(length), _rest::binary>> = value_binary
      value
    else
      offset = Binary.to_integer(value_binary)
      OffsetBuffer.random(buffer, offset, length)
    end
  end

  defp value(_type, :int16u, %OffsetBuffer{} = buffer) do
    <<_length_binary::binary-size(4), value_binary::binary-size(2), _rest::binary>> = buffer.buffer.data
    Binary.to_integer(value_binary)
  end

  defp value(_type, :int32u, %OffsetBuffer{} = buffer) do
    <<_length_binary::binary-size(4), value_binary::binary-size(4), _rest::binary>> = buffer.buffer.data
    Binary.to_integer(value_binary)
  end

  defp value(_type, :rational_64u, %OffsetBuffer{} = buffer) do
    <<count_binary::binary-size(4), offset_binary::binary-size(4), _rest::binary>> = buffer.buffer.data
    rational_count = Binary.to_integer(count_binary)
    value_offset = Binary.to_integer(offset_binary)
    OffsetBuffer.random(buffer, value_offset, rational_count * 8)
    |> Binary.to_rational()
  end

  defp value(_type, :rational_64s, %OffsetBuffer{} = buffer) do
    <<_count_binary::binary-size(4), offset_binary::binary-size(4), _rest::binary>> = buffer.buffer.data
    value_offset = Binary.to_integer(offset_binary)
    OffsetBuffer.random(buffer, value_offset, 8)
    |> Binary.to_signed_rational()
  end
end
