defmodule Exiffer.Rewrite do
  @moduledoc """
  Rewrite an image file, adding and removing arbitrary metadata
  """

  alias Exiffer.Entry
  alias Exiffer.Header.APP1.EXIF
  alias Exiffer.IFD
  alias Exiffer.IFDBlock

  def set_gps(input, gps) do
    entry = build_entry(gps)

    {image, remainder} = Exiffer.parse(input)

    metadata = if has_exif?(image.headers) do
      image.headers
    else
      [blank_exif() | image.headers]
    end

    {:ok, metadata} = apply_gps(metadata, entry)

    {:ok, metadata, remainder}
  end

  defp has_exif?(headers) do
    Enum.any?(headers, fn header -> header.__struct__ == Exif end)
  end

  defp blank_exif do
    ifd_block = %IFDBlock{ifds: []}
    %EXIF{byte_order: :little, ifd_block: ifd_block}
  end

  defp build_entry(gps) do
    latitude_ref = if gps.latitude >= 0, do: "N", else: "S"
    longitude_ref = if gps.longitude >= 0, do: "W", else: "E"
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

  defp apply_gps(headers, entry) do
    {:ok, headers} = remove_gps(headers)
    {:ok, _headers} = add_gps(headers, entry)
  end

  defp add_gps(headers, entry) when is_list(headers) do
    headers = Enum.map(headers, &(add_gps(&1, entry)))
    {:ok, headers}
  end

  defp add_gps(%EXIF{} = exif, entry) do
    ifd_block = add_gps(exif.ifd_block, entry)
    struct!(exif, ifd_block: ifd_block)
  end

  defp add_gps(%IFDBlock{ifds: []} = ifd_block, entry) do
    ifd = %IFD{entries: []}
    ifd = add_gps(ifd, entry)
    struct!(ifd_block, ifds: [ifd])
  end

  defp add_gps(%IFDBlock{} = ifd_block, entry) do
    [ifd | others] = ifd_block.ifds
    ifd = add_gps(ifd, entry)
    struct!(ifd_block, ifds: [ifd | others])
  end

  defp add_gps(%IFD{} = ifd, entry) do
    entries = Enum.reverse([entry | Enum.reverse(ifd.entries)])
    struct!(ifd, entries: entries)
  end

  defp add_gps(item, _entry), do: item

  defp remove_gps(headers) when is_list(headers) do
    headers = Enum.map(headers, &(remove_gps(&1)))
    {:ok, headers}
  end

  defp remove_gps(%EXIF{} = exif) do
    ifd_block = remove_gps(exif.ifd_block)
    struct!(exif, ifd_block: ifd_block)
  end

  defp remove_gps(%IFDBlock{} = ifd_block) do
    ifds = Enum.map(ifd_block.ifds, &(remove_gps(&1)))
    struct!(ifd_block, ifds: ifds)
  end

  defp remove_gps(%IFD{} = ifd) do
    entries =
      ifd.entries
      |> Enum.map(&(remove_gps(&1)))
      |> Enum.filter(&(&1))
    struct!(ifd, entries: entries)
  end

  defp remove_gps(%Entry{type: :gps_info}) do
    nil
  end

  defp remove_gps(item) do
    item
  end
end
