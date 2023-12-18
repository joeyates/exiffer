defmodule Exiffer.Rewrite do
  @moduledoc """
  Rewrite an image file, adding and removing arbitrary metadata
  """

  require Logger

  alias Exiffer.GPS
  alias Exiffer.JPEG.{Entry, IFD, IFDBlock}
  alias Exiffer.JPEG.Header.APP1.EXIF

  def set_gps(%{} = input, %GPS{} = gps) do
    Logger.info("Exiffer.Rewrite.set_gps/2")
    {jpeg, remainder} = Exiffer.parse(input)

    Logger.debug("Adding/updating GPS entry")
    {headers, exif_index} = ensure_exif(jpeg.headers)
    {headers, gps_index} = ensure_entry(headers, exif_index, :gps_info)
    entry = build_gps_entry(gps)
    headers =
      headers
      |> update_in(
        entries_path(exif_index) ++ [Access.at(gps_index)],
        fn _existing -> entry end
      )

    {:ok, headers, remainder}
  end

  defp ensure_exif(headers) do
    index = Enum.find_index(headers, fn header -> header.__struct__ == EXIF end)

    if index do
      {headers, index}
    else
      length = length(headers)
      {headers ++ [blank_exif()], length}
    end
  end

  defp blank_exif do
    %EXIF{
      byte_order: :little,
      ifd_block: %IFDBlock{
        ifds: [%IFD{entries: []}]
      }
    }
  end

  defp ensure_entry(headers, exif_index, type) do
    index = entry_index(headers, exif_index, type)

    if index do
      {headers, index}
    else
      headers =
        headers
        |> update_in(
          entries_path(exif_index),
          fn entries -> [Entry.new_by_type(type, nil) | entries] end
        )

      {headers, 0}
    end
  end

  defp entry_index(headers, exif_index, type) do
    entries = ifd_entries(headers, exif_index)
    Enum.find_index(entries, fn ifd -> ifd.type == type end)
  end

  defp ifd_entries(headers, exif_index) do
    get_in(headers, entries_path(exif_index))
  end

  # We assume there is only one IFD in the EXIF block
  defp entries_path(exif_index) do
    [Access.at(exif_index), Access.key(:ifd_block), Access.key(:ifds), Access.at(0), Access.key(:entries)]
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
end
