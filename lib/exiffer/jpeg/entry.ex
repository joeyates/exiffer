defmodule Exiffer.JPEG.Entry do
  @moduledoc """
  Documentation for `Exiffer.JPEG.Entry`.
  """

  require Logger

  alias Exiffer.Binary
  alias Exiffer.JPEG.IFD
  alias Exiffer.JPEG.Entry.MakerNotes
  import Exiffer.Logging, only: [integer: 1, pair: 1]

  @enforce_keys ~w(type format magic label value)a
  defstruct ~w(type format label magic value)a

  defimpl Jason.Encoder do
    @spec encode(%Exiffer.JPEG.Entry{}, Jason.Encode.opts()) :: String.t()
    def encode(entry, opts) do
      values =
        entry
        |> Exiffer.JPEG.Entry.text()
        |> Enum.map(&present/1)
        |> Enum.into(%{})

      Jason.Encode.map(
        %{
          module: "Exiffer.JPEG.Entry",
          type: entry.type,
          format: entry.format,
          label: entry.label,
          value: values
        },
        opts
      )
    end

    defp present(pair)

    defp present({key, value}) when is_binary(value) do
      if String.printable?(value) do
        value
      else
        Base.encode16(value)
      end
      |> then(& {key, &1})
    end

    defp present({key, value}), do: {key, value}
  end

  # Binaries are big endian

  @format_int8u <<0x00, 0x01>>
  @format_string <<0x00, 0x02>>
  @format_int16u <<0x00, 0x03>>
  @format_int32u <<0x00, 0x04>>
  @format_rational_64u <<0x00, 0x05>>
  @format_raw_bytes <<0x00, 0x07>>
  @format_int32s <<0x00, 0x09>>
  @format_rational_64s <<0x00, 0x0A>>

  @format_type %{
    @format_int8u => :int8u,
    @format_string => :string,
    @format_int16u => :int16u,
    @format_int32u => :int32u,
    @format_rational_64u => :rational_64u,
    @format_raw_bytes => :raw_bytes,
    @format_int32s => :int32s,
    @format_rational_64s => :rational_64s
  }

  @format %{
    int8u: %{magic: @format_int8u, type: :int8u, name: "8-bit integer"},
    string: %{magic: @format_string, type: :string, name: "String"},
    int16u: %{magic: @format_int16u, type: :int16u, name: "16-bit integer"},
    int32u: %{magic: @format_int32u, type: :int32u, name: "32-bit integer"},
    rational_64u: %{magic: @format_rational_64u, type: :rational_64u, name: "64-bit rational"},
    raw_bytes: %{magic: @format_raw_bytes, type: :raw_bytes, name: "Raw bytes"},
    int32s: %{magic: @format_int32s, type: :int32s, name: "32-bit signed integer"},
    rational_64s: %{
      magic: @format_rational_64s,
      type: :rational_64s,
      name: "64-bit signed rational"
    }
  }

  # Map format magic to format type
  @format_type Enum.into(@format, %{}, fn {type, %{magic: magic}} -> {magic, type} end)

  @doc "Formats whose data fits in 4 bytes"

  # Map entry type to entry info
  # TODO: sort by type
  @entry_info %{
    version: %{type: :version, magic: <<0x00, 0x00>>, formats: [:raw_bytes], label: "Version"},
    gps_latitude_ref: %{
      type: :gps_latitude_ref,
      magic: <<0x00, 0x01>>,
      formats: [:string],
      label: "GPS Latitude Ref"
    },
    gps_latitude: %{
      type: :gps_latitude,
      magic: <<0x00, 0x02>>,
      formats: [:rational_64u, :rational_64s],
      label: "GPS Latitude"
    },
    gps_longitude_ref: %{
      type: :gps_longitude_ref,
      magic: <<0x00, 0x03>>,
      formats: [:string],
      label: "GPS Longitude Ref"
    },
    gps_longitude: %{
      type: :gps_longitude,
      magic: <<0x00, 0x04>>,
      formats: [:rational_64u, :rational_64s],
      label: "GPS Longitude"
    },
    gps_altitude_ref: %{
      type: :gps_altitude_ref,
      magic: <<0x00, 0x05>>,
      formats: [:int16u],
      label: "GPS Altitude Ref"
    },
    gps_altitude: %{
      type: :gps_altitude,
      magic: <<0x00, 0x06>>,
      formats: [:rational_64u],
      label: "GPS Altitude"
    },
    gps_time_stamp: %{
      type: :gps_time_stamp,
      magic: <<0x00, 0x07>>,
      formats: [:rational_64u],
      label: "GPS Time Stamp"
    },
    processing_software: %{
      type: :processing_software,
      magic: <<0x00, 0x0B>>,
      formats: [:string],
      label: "Processing Software"
    },
    gps_date_stamp: %{
      type: :gps_date_stamp,
      magic: <<0x00, 0x1D>>,
      formats: [:string],
      label: "GPS Date Stamp"
    },
    image_width: %{
      type: :image_width,
      magic: <<0x01, 0x00>>,
      formats: [:int32u, :int32s],
      label: "Image Width"
    },
    image_height: %{
      type: :image_height,
      magic: <<0x01, 0x01>>,
      formats: [:int32u, :int32s],
      label: "Image Height"
    },
    compression: %{
      type: :compression,
      magic: <<0x01, 0x03>>,
      formats: [:int16u],
      label: "Compression"
    },
    image_description: %{
      type: :image_description,
      magic: <<0x01, 0x0E>>,
      formats: [:string],
      label: "Image Description"
    },
    make: %{type: :make, magic: <<0x01, 0x0F>>, formats: [:string], label: "Make"},
    model: %{type: :model, magic: <<0x01, 0x10>>, formats: [:string], label: "Model"},
    orientation: %{
      type: :orientation,
      magic: <<0x01, 0x12>>,
      formats: [:int16u, :int32s],
      label: "Orientation"
    },
    x_resolution: %{
      type: :x_resolution,
      magic: <<0x01, 0x1A>>,
      formats: [:rational_64u],
      label: "X Resolution"
    },
    y_resolution: %{
      type: :y_resolution,
      magic: <<0x01, 0x1B>>,
      formats: [:rational_64u],
      label: "Y Resolution"
    },
    resolution_unit: %{
      type: :resolution_unit,
      magic: <<0x01, 0x28>>,
      formats: [:int16u],
      label: "Resolution Unit"
    },
    software: %{type: :software, magic: <<0x01, 0x31>>, formats: [:string], label: "Software"},
    host_computer: %{
      type: :host_computer,
      magic: <<0x01, 0x3C>>,
      formats: [:string],
      label: "Host Computer"
    },
    modification_date: %{
      type: :modification_date,
      magic: <<0x01, 0x32>>,
      formats: [:string],
      label: "Modification Date"
    },
    thumbnail_offset: %{
      type: :thumbnail_offset,
      magic: <<0x02, 0x01>>,
      formats: [:int32u],
      label: "Thumbnail Offset"
    },
    thumbnail_length: %{
      type: :thumbnail_length,
      magic: <<0x02, 0x02>>,
      formats: [:int32u],
      label: "Thumbnail Length"
    },
    ycbcr_positioning: %{
      type: :ycbcr_positioning,
      magic: <<0x02, 0x13>>,
      formats: [:int16u],
      label: "Ycbcr Positioning"
    },
    quality: %{type: :quality, magic: <<0x10, 0x00>>, formats: [:string], label: "Quality"},
    sharpness: %{type: :sharpness, magic: <<0x10, 0x01>>, formats: [:int16u], label: "Sharpness"},
    fuji_white_balance: %{
      type: :fuji_white_balance,
      magic: <<0x10, 0x02>>,
      formats: [:int16u],
      label: "FUJI White Balance"
    },
    fuji_flash_mode: %{
      type: :fuji_flash_mode,
      magic: <<0x10, 0x10>>,
      formats: [:int16u],
      label: "Fuji Flash Mode"
    },
    # FlashExposureComp seems to be flash strength
    flash_exposure_comp: %{
      type: :flash_exposure_comp,
      magic: <<0x10, 0x11>>,
      formats: [:rational_64s],
      label: "Flash Exposure Comp"
    },
    macro: %{type: :macro, magic: <<0x10, 0x20>>, formats: [:int16u], label: "Macro"},
    focus_mode: %{
      type: :focus_mode,
      magic: <<0x10, 0x21>>,
      formats: [:int16u],
      label: "Focus Mode"
    },
    slow_sync: %{type: :slow_sync, magic: <<0x10, 0x30>>, formats: [:int16u], label: "Slow Sync"},
    picture_mode: %{
      type: :picture_mode,
      magic: <<0x10, 0x31>>,
      formats: [:int16u],
      label: "Picture Mode"
    },
    auto_bracketing: %{
      type: :auto_bracketing,
      magic: <<0x11, 0x00>>,
      formats: [:int16u],
      label: "Auto Bracketing"
    },
    blur_warning: %{
      type: :blur_warning,
      magic: <<0x13, 0x00>>,
      formats: [:int16u],
      label: "Blur Warning"
    },
    focus_warning: %{
      type: :focus_warning,
      magic: <<0x13, 0x01>>,
      formats: [:int16u],
      label: "Focus Warning"
    },
    exposure_warning: %{
      type: :exposure_warning,
      magic: <<0x13, 0x02>>,
      formats: [:int16u],
      label: "Exposure Warning"
    },
    exif_offset: %{
      type: :exif_offset,
      magic: <<0x87, 0x69>>,
      formats: [:int32u],
      label: "Exif Offset"
    },
    gps_info: %{type: :gps_info, magic: <<0x88, 0x25>>, formats: [:int32u], label: "GPSInfo"},
    copyright: %{type: :copyright, magic: <<0x82, 0x98>>, formats: [:string], label: "Copyright"},
    exposure_time: %{
      type: :exposure_time,
      magic: <<0x82, 0x9A>>,
      formats: [:rational_64u],
      label: "Exposure Time"
    },
    f_number: %{
      type: :f_number,
      magic: <<0x82, 0x9D>>,
      formats: [:rational_64u],
      label: "F Number"
    },
    exposure_program: %{
      type: :exposure_program,
      magic: <<0x88, 0x22>>,
      formats: [:int16u],
      label: "Exposure Program"
    },
    iso: %{type: :iso, magic: <<0x88, 0x27>>, formats: [:int16u], label: "Iso"},
    exif_version: %{
      type: :exif_version,
      magic: <<0x90, 0x00>>,
      formats: [:string, :raw_bytes],
      label: "Exif Version"
    },
    date_time_original: %{
      type: :date_time_original,
      magic: <<0x90, 0x03>>,
      formats: [:string],
      label: "Date Time Original"
    },
    create_date: %{
      type: :create_date,
      magic: <<0x90, 0x04>>,
      formats: [:string],
      label: "Create Date"
    },
    offset_time: %{
      type: :offset_time,
      magic: <<0x90, 0x10>>,
      formats: [:string],
      label: "Offset Time"
    },
    offset_time_original: %{
      type: :offset_time_original,
      magic: <<0x90, 0x11>>,
      formats: [:string],
      label: "Offset Time Original"
    },
    components_configuration: %{
      type: :components_configuration,
      magic: <<0x91, 0x01>>,
      formats: [:raw_bytes],
      label: "Components Configuration"
    },
    compressed_bits_per_pixel: %{
      type: :compressed_bits_per_pixel,
      magic: <<0x91, 0x02>>,
      formats: [:rational_64u],
      label: "Compressed Bits Per Pixel"
    },
    shutter_speed_value: %{
      type: :shutter_speed_value,
      magic: <<0x92, 0x01>>,
      formats: [:rational_64u, :rational_64s],
      label: "Shutter Speed Value"
    },
    aperture_value: %{
      type: :aperture_value,
      magic: <<0x92, 0x02>>,
      formats: [:rational_64u],
      label: "Aperture Value"
    },
    brightness_value: %{
      type: :brightness_value,
      magic: <<0x92, 0x03>>,
      formats: [:rational_64s],
      label: "Brightness Value"
    },
    exposure_compensation: %{
      type: :exposure_compensation,
      magic: <<0x92, 0x04>>,
      formats: [:rational_64s],
      label: "Exposure Compensation"
    },
    max_aperture_value: %{
      type: :max_aperture_value,
      magic: <<0x92, 0x05>>,
      formats: [:rational_64u],
      label: "Max Aperture Value"
    },
    subject_distance: %{
      type: :subject_distance,
      magic: <<0x92, 0x06>>,
      formats: [:rational_64u],
      label: "Subject Distance"
    },
    metering_mode: %{
      type: :metering_mode,
      magic: <<0x92, 0x07>>,
      formats: [:int16u],
      label: "Metering Mode"
    },
    light_source: %{
      type: :light_source,
      magic: <<0x92, 0x08>>,
      formats: [:int16u],
      label: "Light Source"
    },
    flash: %{type: :flash, magic: <<0x92, 0x09>>, formats: [:int16u], label: "Flash"},
    focal_length: %{
      type: :focal_length,
      magic: <<0x92, 0x0A>>,
      formats: [:rational_64u],
      label: "Focal Length"
    },
    maker_notes: %{
      type: :maker_notes,
      magic: <<0x92, 0x7C>>,
      formats: [:int8u, :raw_bytes, :string],
      label: "Maker Notes"
    },
    user_comment: %{
      type: :user_comment,
      magic: <<0x92, 0x86>>,
      formats: [:string, :raw_bytes],
      label: "User Comment"
    },
    sub_sec_time: %{
      type: :sub_sec_time,
      magic: <<0x92, 0x90>>,
      formats: [:string],
      label: "Sub Sec Time"
    },
    sub_sec_time_original: %{
      type: :sub_sec_time_original,
      magic: <<0x92, 0x91>>,
      formats: [:string],
      label: "Sub Sec Time Original"
    },
    sub_sec_time_digitized: %{
      type: :sub_sec_time_digitized,
      magic: <<0x92, 0x92>>,
      formats: [:string],
      label: "Sub Sec Time Digitized"
    },
    xp_keywords: %{
      type: :xp_keywords,
      magic: <<0x9C, 0x9E>>,
      formats: [:string],
      label: "XPKeywords"
    },
    flashpix_version: %{
      type: :flashpix_version,
      magic: <<0xA0, 0x00>>,
      formats: [:raw_bytes],
      label: "Flashpix Version"
    },
    color_space: %{
      type: :color_space,
      magic: <<0xA0, 0x01>>,
      formats: [:int16u],
      label: "Color Space"
    },
    exif_image_width: %{
      type: :exif_image_width,
      magic: <<0xA0, 0x02>>,
      formats: [:int16u, :int32u, :int32s],
      label: "Exif Image Width"
    },
    exif_image_height: %{
      type: :exif_image_height,
      magic: <<0xA0, 0x03>>,
      formats: [:int16u, :int32u, :int32s],
      label: "Exif Image Height"
    },
    related_sound_file: %{
      type: :related_sound_file,
      magic: <<0xA0, 0x04>>,
      formats: [:string],
      label: "Related Sound File"
    },
    interop_offset: %{
      type: :interop_offset,
      magic: <<0xA0, 0x05>>,
      formats: [:int32u],
      label: "Interop Offset"
    },
    focal_plane_x_resolution: %{
      type: :focal_plane_x_resolution,
      magic: <<0xA2, 0x0E>>,
      formats: [:rational_64u],
      label: "Focal Plane X Resolution"
    },
    focal_plane_y_resolution: %{
      type: :focal_plane_y_resolution,
      magic: <<0xA2, 0x0F>>,
      formats: [:rational_64u],
      label: "Focal Plane Y Resolution"
    },
    focal_plane_resolution_unit: %{
      type: :focal_plane_resolution_unit,
      magic: <<0xA2, 0x10>>,
      formats: [:int16u],
      label: "Focal Plane Resolution Unit"
    },
    exposure_index: %{
      type: :exposure_index,
      magic: <<0xA2, 0x15>>,
      formats: [:rational_64u],
      label: "Exposure Index"
    },
    sensing_method: %{
      type: :sensing_method,
      magic: <<0xA2, 0x17>>,
      formats: [:int16u],
      label: "Sensing Method"
    },
    file_source: %{
      type: :file_source,
      magic: <<0xA3, 0x00>>,
      formats: [:raw_bytes],
      label: "File Source"
    },
    scene_type: %{
      type: :scene_type,
      magic: <<0xA3, 0x01>>,
      formats: [:raw_bytes],
      label: "Scene Type"
    },
    custom_rendered: %{
      type: :custom_rendered,
      magic: <<0xA4, 0x01>>,
      formats: [:int16u],
      label: "Custom Rendered"
    },
    exposure_mode: %{
      type: :exposure_mode,
      magic: <<0xA4, 0x02>>,
      formats: [:int16u],
      label: "Exposure Mode"
    },
    exif_white_balance: %{
      type: :exif_white_balance,
      magic: <<0xA4, 0x03>>,
      formats: [:int16u],
      label: "EXIF White Balance"
    },
    digital_zoom_ratio: %{
      type: :digital_zoom_ratio,
      magic: <<0xA4, 0x04>>,
      formats: [:rational_64u],
      label: "Digital Zoom Ratio"
    },
    focal_length_in_35mm_format: %{
      type: :focal_length_in_35mm_format,
      magic: <<0xA4, 0x05>>,
      formats: [:int16u],
      label: "Focal Length In 35mm Format"
    },
    scene_capture_type: %{
      type: :scene_capture_type,
      magic: <<0xA4, 0x06>>,
      formats: [:int16u],
      label: "Scene Capture Type"
    },
    gain_control: %{
      type: :gain_control,
      magic: <<0xA4, 0x07>>,
      formats: [:int16u],
      label: "Gain Control"
    },
    contrast: %{type: :contrast, magic: <<0xA4, 0x08>>, formats: [:int16u], label: "Contrast"},
    saturation: %{
      type: :saturation,
      magic: <<0xA4, 0x09>>,
      formats: [:int16u],
      label: "Saturation"
    },
    sharpness_2: %{
      type: :sharpness_2,
      magic: <<0xA4, 0x0A>>,
      formats: [:int16u],
      label: "EXIF Sharpness"
    },
    subject_distance_range: %{
      type: :subject_distance_range,
      magic: <<0xA4, 0x0C>>,
      formats: [:int16u],
      label: "Subject Distance Range"
    },
    image_unique_id: %{
      type: :image_unique_id,
      magic: <<0xA4, 0x20>>,
      formats: [:string],
      label: "Image Unique Id"
    },
    print_im: %{type: :print_im, magic: <<0xC4, 0xA5>>, formats: [:raw_bytes], label: "Print IM"},
    panasonic_title: %{
      type: :panasonic_title,
      magic: <<0xC6, 0xD2>>,
      formats: [:raw_bytes],
      label: "Panasonic Title"
    },
    padding: %{type: :padding, magic: <<0xEA, 0x1C>>, formats: [:raw_bytes], label: "Padding"},
    offset_schema: %{
      type: :offset_schema,
      magic: <<0xEA, 0x1D>>,
      formats: [:int32s],
      label: "Offset Schema"
    }
  }

  # Interop IFD entries reuse generic entry magic numbers, so we use a specific table for them
  @interop_entry_info %{
    interop_index: %{
      type: :interop_index,
      magic: <<0x00, 0x01>>,
      formats: [:string],
      label: "Interop Index"
    },
    interop_version: %{
      type: :interop_version,
      magic: <<0x00, 0x02>>,
      formats: [:raw_bytes],
      label: "Interop Version"
    },
    related_image_width: %{
      type: :related_image_width,
      magic: <<0x10, 0x01>>,
      formats: [:int16u],
      label: "Related Image Width"
    },
    related_image_height: %{
      type: :related_image_height,
      magic: <<0x10, 0x02>>,
      formats: [:int16u],
      label: "Related Image Height"
    }
  }

  @maker_notes_entry_info %{
    maker_note_version: %{
      type: :maker_note_version,
      magic: <<0x00, 0x01>>,
      formats: [:raw_bytes],
      label: "Maker Note Version"
    },
    device_type: %{
      type: :device_type,
      magic: <<0x00, 0x02>>,
      formats: [:int32u],
      label: "Device Type"
    },
    raw_data_byte_order: %{
      type: :raw_data_byte_order,
      magic: <<0x00, 0x40>>,
      formats: [:int32u],
      label: "Raw Data Byte Order"
    },
    raw_data_cfa_pattern: %{
      type: :raw_data_cfa_pattern,
      magic: <<0x00, 0x50>>,
      formats: [:int32u],
      label: "Raw Data CFA Pattern"
    },
    face_detect: %{
      type: :face_detect,
      magic: <<0x01, 0x00>>,
      formats: [:int16u],
      label: "Face Detect"
    }
  }

  @entry_info_map %{
    nil: @entry_info,
    interop: @interop_entry_info,
    maker_notes: @maker_notes_entry_info
  }

  # Map magic numbers to entry types
  @entry_type Enum.into(@entry_info, %{}, fn {type, %{magic: magic}} -> {magic, type} end)
  @interop_entry_type Enum.into(@interop_entry_info, %{}, fn {type, %{magic: magic}} ->
                        {magic, type}
                      end)
  @maker_notes_entry_type Enum.into(@maker_notes_entry_info, %{}, fn {type, %{magic: magic}} ->
                            {magic, type}
                          end)

  @entry_type_map %{
    nil: @entry_type,
    interop: @interop_entry_type,
    maker_notes: @maker_notes_entry_type
  }

  @override %{
    interop_offset: :interop,
    maker_notes: :maker_notes
  }

  def new(%{} = buffer, opts \\ []) do
    position = Exiffer.Buffer.tell(buffer)
    Logger.debug("Reading IFD Entry at #{integer(position)}")
    override = Keyword.get(opts, :override)
    entry_type_map = @entry_type_map[override]
    {magic, buffer} = Exiffer.Buffer.consume(buffer, 2)
    big_endian_magic = Binary.big_endian(magic)
    Logger.debug("Found entry magic #{pair(big_endian_magic)}")
    entry_table = @entry_info_map[override]
    {format_magic, buffer} = Exiffer.Buffer.consume(buffer, 2)
    big_endian_format_magic = Binary.big_endian(format_magic)
    Logger.debug("Found format magic #{pair(big_endian_format_magic)}")

    with {:ok, format_type} <- format_type(big_endian_format_magic),
         entry_type <- entry_type_map[big_endian_magic] do
      Logger.debug("Found entry type '#{entry_type}' and format #{format_type}")

      entry =
        case entry_type do
          nil ->
            offset = buffer.offset

            Logger.warning(
              "Unknown IFD entry magic #{pair(big_endian_magic)} (big endian) found at #{integer(position)}, (offset #{integer(offset + position)})"
            )

            value = value(:unknown, format_type, buffer)
            label = "Unknown entry tag #{pair(big_endian_magic)}"

            %__MODULE__{
              type: :unknown,
              format: format_type,
              value: value,
              label: label,
              magic: big_endian_magic
            }

          entry_type ->
            info = entry_table[entry_type]

            if format_type not in info.formats do
              offset = buffer.offset
              expected = Enum.map(info.formats, &@format[&1].name) |> Enum.join(" or ")

              Logger.warning(
                "'#{info.label}' Entry, found format #{format_type} expected to be #{expected}, at #{integer(position)}, (offset #{integer(offset + position)})"
              )
            end

            value = value(info.type, format_type, buffer)

            %__MODULE__{
              type: info.type,
              format: format_type,
              value: value,
              label: info.label,
              magic: big_endian_magic
            }
        end

      buffer = Exiffer.Buffer.skip(buffer, 8)
      {entry, buffer}
    else
      {:error, :unknown_format_magic} ->
        message = "Unknown format magic #{inspect(big_endian_format_magic, base: :hex)}"
        Logger.error(message)
        {nil, buffer}
    end
  end

  def new_by_type(type, value) do
    entry_table = @entry_info_map[nil]
    info = entry_table[type]
    format_type = hd(info.formats)

    %__MODULE__{
      type: type,
      format: format_type,
      value: value,
      label: info.label,
      magic: info.magic
    }
  end

  defp format_type(big_endian_format_magic) do
    case @format_type[big_endian_format_magic] do
      nil ->
        {:error, :unknown_format_magic}

      format_type ->
        {:ok, format_type}
    end
  end

  def format_name(%__MODULE__{format: format}) do
    @format[format].name
  end

  @doc """
  Returns a two-ple {ifd_entry, ifd_extra_data},
  where ifd_extra_data is `<<>>` if there is none to be added.
  """
  def binary(entry, end_of_block)

  def binary(%__MODULE__{type: type} = entry, end_of_block)
      when type in [:exif_offset, :gps_info, :interop_offset] do
    magic_binary = Binary.big_endian_to_current(entry.magic)

    format_binary =
      @format[entry.format].magic
      |> Binary.big_endian_to_current()

    size_binary = Binary.int32u_to_current(1)
    value = Binary.int32u_to_current(end_of_block)
    header = <<magic_binary::binary, format_binary::binary, size_binary::binary, value::binary>>
    override = @override[type]
    opts = if override, do: [override: override], else: []
    extra = IFD.binary(entry.value, end_of_block, opts)
    {header, extra}
  end

  def binary(%__MODULE__{} = entry, end_of_block) do
    magic_binary = Binary.big_endian_to_current(entry.magic)

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
  def text(entry)

  def text(%__MODULE__{type: :gps_info} = entry) do
    texts =
      entry.value.entries
      |> Enum.flat_map(&text(&1))

    [{"Interop", nil} | texts]
  end

  def text(%__MODULE__{type: :interop_offset} = entry) do
    texts =
      entry.value.entries
      |> Enum.flat_map(&text(&1))

    [{"Interop", nil} | texts]
  end

  def text(%__MODULE__{type: :exif_offset} = entry) do
    texts =
      entry.value.entries
      |> Enum.map(&text(&1))
      |> Enum.sort_by(&length(&1))
      |> List.flatten()

    [{"EXIF", nil} | texts]
  end

  def text(%__MODULE__{type: :thumbnail_offset} = _entry) do
    []
  end

  def text(%__MODULE__{type: :maker_notes, value: %MakerNotes{}} = entry) do
    texts =
      entry.value.ifd.entries
      |> Enum.flat_map(&text(&1))

    [{"Maker Notes", nil} | texts]
  end

  def text(%__MODULE__{format: :int8u} = entry) do
    [{entry.label, entry.value}]
  end

  def text(%__MODULE__{format: :string} = entry) do
    [{entry.label, entry.value}]
  end

  def text(%__MODULE__{format: format} = entry) when format in [:int16u, :int32u, :int32s] do
    [{entry.label, Integer.to_string(entry.value)}]
  end

  def text(%__MODULE__{format: :rational_64u} = entry) do
    [{entry.label, rational64u_to_string(entry.value)}]
  end

  def text(%__MODULE__{format: :raw_bytes} = entry) do
    [{entry.label, inspect(entry.value, base: :hex)}]
  end

  # TODO: handle negatives
  def text(%__MODULE__{format: :rational_64s, value: {_numerator, 0}} = entry) do
    [{entry.label, 0}]
  end

  def text(%__MODULE__{format: :rational_64s} = entry) do
    {numerator, denominator} = entry.value
    value = numerator / denominator
    [{entry.label, Float.to_string(value)}]
  end

  defp data(%__MODULE__{type: :maker_notes, value: %MakerNotes{} = value}, end_of_block) do
    previous_byte_order = Binary.byte_order()
    Binary.set_byte_order(:little)
    binary = IFD.binary(value.ifd, 0)
    Binary.set_byte_order(previous_byte_order)
    size = byte_size(binary)
    value = Binary.int32u_to_current(end_of_block)
    {size, value, binary}
  end

  defp data(%__MODULE__{type: :thumbnail_offset} = entry, end_of_block) do
    value = Binary.int32u_to_current(end_of_block)
    extra = entry.value
    {1, value, extra}
  end

  defp data(%__MODULE__{format: :int8u} = entry, _end_of_block) do
    value = <<entry.value, 0x00, 0x00, 0x00>>
    {1, value, <<>>}
  end

  defp data(%__MODULE__{format: :int16u} = entry, _end_of_block) do
    value = <<Binary.int16u_to_current(entry.value)::binary, 0x00, 0x00>>
    {1, value, <<>>}
  end

  defp data(%__MODULE__{format: :int32u} = entry, _end_of_block) do
    value = Binary.int32u_to_current(entry.value)
    {1, value, <<>>}
  end

  defp data(%__MODULE__{format: format} = entry, end_of_block)
       when format in [:string, :raw_bytes] do
    size = byte_size(entry.value)

    if size <= 4 do
      pad_count = 4 - size
      reported_size = if size < 4, do: size + 1, else: size
      <<padding::binary-size(pad_count), _rest::binary>> = <<0, 0, 0, 0>>
      {reported_size, <<entry.value::binary, padding::binary>>, <<>>}
    else
      # Always add a final NULL after strings added after the block
      size = size + 1
      value = <<entry.value::binary, 0x00>>

      extra =
        if rem(size, 2) == 1 do
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

  defp rational64u_to_string(value)

  defp rational64u_to_string(values) when is_list(values) do
    values
    |> Enum.map(&rational64u_to_string/1)
    |> Enum.join(", ")
  end

  defp rational64u_to_string({_, 0}) do
    "nil"
  end

  defp rational64u_to_string({numerator, denominator}) do
    (numerator / denominator)
    |> Float.to_string()
  end

  defp read_ifd(%{} = buffer, offset, opts \\ []) do
    position = Exiffer.Buffer.tell(buffer)
    buffer = Exiffer.Buffer.seek(buffer, offset)
    {:ok, ifd, buffer} = IFD.read(buffer, opts)
    _buffer = Exiffer.Buffer.seek(buffer, position)
    ifd
  end

  defp value(:interop_offset, :int32u, %{} = buffer) do
    <<_size_binary::binary-size(4), offset_binary::binary-size(4), _rest::binary>> =
      buffer.buffer.data

    offset = Binary.to_integer(offset_binary)
    read_ifd(buffer, offset, override: :interop)
  end

  defp value(type, :int32u, %{} = buffer) when type in [:exif_offset, :gps_info] do
    <<_size_binary::binary-size(4), offset_binary::binary-size(4), _rest::binary>> =
      buffer.buffer.data

    offset = Binary.to_integer(offset_binary)
    read_ifd(buffer, offset)
  end

  defp value(:maker_notes, :raw_bytes, %{} = buffer) do
    position = Exiffer.Buffer.tell(buffer)
    Logger.debug("Reading maker notes at #{integer(position)}")

    <<length_binary::binary-size(4), offset_binary::binary-size(4), _rest::binary>> =
      buffer.buffer.data

    # Maker notes have their own offset into the file
    offset = Binary.to_integer(offset_binary)
    notes_offset = buffer.offset + offset
    Logger.debug("Maker notes offset: #{integer(offset)} (absolute #{integer(notes_offset)})")
    length = Binary.to_integer(length_binary)
    Logger.debug("Maker notes length: #{integer(length)}")
    # See if the maker notes are a parsable IFD
    file_byte_order = Binary.byte_order()

    result =
      try do
        notes_buffer =
          Exiffer.Buffer.offset_buffer(buffer.buffer, notes_offset)
          |> Exiffer.Buffer.seek(0)

        # Temporarily set process-local byte order
        Binary.set_byte_order(:little)
        Logger.debug("Reading maker notes IFD")
        {:ok, ifd, buffer} = IFD.read(notes_buffer, override: :maker_notes)
        _buffer = Exiffer.Buffer.seek(buffer, position)
        %MakerNotes{ifd: ifd}
      rescue
        _e ->
          Logger.debug("Maker notes are not an IFD, falling back to reading as raw bytes")
          Exiffer.Buffer.random(buffer, offset, length)
      end

    Binary.set_byte_order(file_byte_order)
    result
  end

  defp value(_type, format, %{} = buffer) when format in [:string, :raw_bytes] do
    <<length_binary::binary-size(4), value_binary::binary-size(4), _rest::binary>> =
      buffer.buffer.data

    length = Binary.to_integer(length_binary)

    cond do
      length == 0 ->
        ""

      length <= 4 and format == :string ->
        # Ignore the trailing zero byte
        length = length - 1
        <<value::binary-size(length), _rest::binary>> = value_binary
        value

      length <= 4 ->
        <<value::binary-size(length), _rest::binary>> = value_binary
        value

      true ->
        offset = Binary.to_integer(value_binary)
        string = Exiffer.Buffer.random(buffer, offset, length)

        if :binary.last(string) == 0 do
          :binary.part(string, {0, length - 1})
        else
          string
        end
    end
  end

  defp value(_type, :int8u, %{} = buffer) do
    <<_length_binary::binary-size(4), value_binary::binary-size(2), _rest::binary>> =
      buffer.buffer.data

    Binary.to_integer(value_binary)
  end

  defp value(_type, :int16u, %{} = buffer) do
    <<_length_binary::binary-size(4), value_binary::binary-size(2), _rest::binary>> =
      buffer.buffer.data

    Binary.to_integer(value_binary)
  end

  defp value(_type, :int32u, %{} = buffer) do
    <<_length_binary::binary-size(4), value_binary::binary-size(4), _rest::binary>> =
      buffer.buffer.data

    Binary.to_integer(value_binary)
  end

  defp value(_type, :rational_64u, %{} = buffer) do
    <<count_binary::binary-size(4), offset_binary::binary-size(4), _rest::binary>> =
      buffer.buffer.data

    rational_count = Binary.to_integer(count_binary)
    value_offset = Binary.to_integer(offset_binary)

    Exiffer.Buffer.random(buffer, value_offset, rational_count * 8)
    |> Binary.to_rational()
  end

  defp value(_type, :int32s, %{} = buffer) do
    <<_length_binary::binary-size(4), value_binary::binary-size(4), _rest::binary>> =
      buffer.buffer.data

    Binary.to_signed(value_binary)
  end

  defp value(_type, :rational_64s, %{} = buffer) do
    <<_count_binary::binary-size(4), offset_binary::binary-size(4), _rest::binary>> =
      buffer.buffer.data

    value_offset = Binary.to_integer(offset_binary)

    Exiffer.Buffer.random(buffer, value_offset, 8)
    |> Binary.to_signed_rational()
  end
end
