defmodule Exiffer.Rewrite do
  @moduledoc """
  Rewrite an image file, adding and removing arbitrary metadata
  """

  require Logger

  alias Exiffer.GPS
  alias Exiffer.JPEG.{Entry, IFD, IFDBlock}
  alias Exiffer.JPEG.Header.APP1.EXIF

  def set_gps(%{} = input, %GPS{} = gps) do
    Logger.info "Exiffer.Rewrite.set_gps/2"
    {image, remainder} = Exiffer.parse(input)
    Logger.info "Parsing complete"

    has_exif = has_exif?(image.headers)
    metadata = if has_exif do
      image.headers
    else
      [blank_exif() | image.headers]
    end

    Logger.info "Adding/updating GPS entry"
    entry = build_gps_entry(gps)
    {:ok, metadata} = set_exif_ifd_entry(metadata, :gps_info, entry)

    Logger.info "Exiffer.Rewrite.set_gps/2 - complete"
    {:ok, metadata, remainder}
  end

  defp has_exif?(headers) do
    Enum.any?(headers, fn header -> header.__struct__ == EXIF end)
  end

  defp blank_exif do
    ifd_block = %IFDBlock{ifds: []}
    %EXIF{byte_order: :little, ifd_block: ifd_block}
  end

  defp build_gps_entry(gps) do
    latitude_ref = if gps.latitude >= 0, do: "N", else: "S"
    longitude_ref = if gps.longitude >= 0, do: "E", else: "W"
    latitude = gps.latitude |> float_to_dms() |> dms_to_rational()
    longitude = gps.longitude |> float_to_dms() |> dms_to_rational()
    altitude = floor(gps.altitude)

    value = %IFD{
      entries: [
        Entry.new_by_type(:gps_latitude_ref, latitude_ref),
        Entry.new_by_type(:gps_latitude, latitude),
        Entry.new_by_type(:gps_longitude_ref, longitude_ref),
        Entry.new_by_type(:gps_longitude, longitude),
        Entry.new_by_type(:gps_altitude_ref, 0),
        Entry.new_by_type(:gps_altitude, {altitude, 1})
      ]
    }
    Entry.new_by_type(:gps_info, value)
  end

  defp float_to_dms(f) do
    abs = abs(f)
    degrees = floor(abs)
    degrees_remainder = abs - degrees
    minutes = floor(60 * degrees_remainder)
    minutes_remainder = degrees_remainder - minutes / 60
    seconds = 3600 * minutes_remainder
    {degrees, minutes, seconds}
  end

  defp dms_to_rational({d, m, s}) do
    mus = floor(s * 1_000_000)
    [{d, 1}, {m, 1}, {mus, 1_000_000}]
  end

  defp set_exif_ifd_entry(headers, type, entry) do
    {:ok, headers} = remove_exif_ifd_entry(headers, type)
    {:ok, _headers} = add_exif_ifd_entry(headers, entry)
  end

  defp add_exif_ifd_entry(headers, entry) when is_list(headers) do
    headers = Enum.map(headers, &(add_exif_ifd_entry(&1, entry)))
    {:ok, headers}
  end

  defp add_exif_ifd_entry(%EXIF{} = exif, entry) do
    ifd_block = add_exif_ifd_entry(exif.ifd_block, entry)
    struct!(exif, ifd_block: ifd_block)
  end

  defp add_exif_ifd_entry(%IFDBlock{ifds: []} = ifd_block, entry) do
    ifd = %IFD{entries: []}
    ifd = add_exif_ifd_entry(ifd, entry)
    struct!(ifd_block, ifds: [ifd])
  end

  defp add_exif_ifd_entry(%IFDBlock{} = ifd_block, entry) do
    [ifd | others] = ifd_block.ifds
    ifd = add_exif_ifd_entry(ifd, entry)
    struct!(ifd_block, ifds: [ifd | others])
  end

  defp add_exif_ifd_entry(%IFD{} = ifd, entry) do
    entries = Enum.reverse([entry | Enum.reverse(ifd.entries)])
    struct!(ifd, entries: entries)
  end

  defp add_exif_ifd_entry(item, _entry), do: item

  defp remove_exif_ifd_entry(headers, type) when is_list(headers) do
    headers = Enum.map(headers, &(remove_exif_ifd_entry(&1, type)))
    {:ok, headers}
  end

  defp remove_exif_ifd_entry(%EXIF{} = exif, type) do
    ifd_block = remove_exif_ifd_entry(exif.ifd_block, type)
    struct!(exif, ifd_block: ifd_block)
  end

  defp remove_exif_ifd_entry(%IFDBlock{} = ifd_block, type) do
    ifds = Enum.map(ifd_block.ifds, &(remove_exif_ifd_entry(&1, type)))
    struct!(ifd_block, ifds: ifds)
  end

  defp remove_exif_ifd_entry(%IFD{} = ifd, type) do
    entries =
      ifd.entries
      |> Enum.map(&(remove_exif_ifd_entry(&1, type)))
      |> Enum.filter(&(&1))
    struct!(ifd, entries: entries)
  end

  defp remove_exif_ifd_entry(%Entry{type: type}, type) do
    nil
  end

  defp remove_exif_ifd_entry(item, _type) do
    item
  end
end
