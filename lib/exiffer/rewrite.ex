defmodule Exiffer.Rewrite do
  @moduledoc """
  Rewrite an image file, adding and removing arbitrary metadata
  """

  require Logger

  alias Exiffer.GPS
  alias Exiffer.JPEG.{Entry, IFD, IFDBlock}
  alias Exiffer.JPEG.Header.APP1.EXIF

  def set_date_time(%{} = input, %DateTime{} = date_time) do
    set_date_time(input, DateTime.to_naive(date_time))
  end

  def set_date_time(%{} = input, %NaiveDateTime{} = date_time) do
    Logger.info("Exiffer.Rewrite.set_date_time/2")
    {jpeg, remainder} = Exiffer.parse(input)
    date_time_text = NaiveDateTime.to_string(date_time)

    Logger.debug("Adding/updating date/time original entry")
    {headers, exif_index} = ensure_exif(jpeg.headers)

    # Modification Date
    {headers, modification_date_index} = ensure_entry(headers, exif_index, :modification_date)
    modification_date = Entry.new_by_type(:modification_date, date_time_text)
    headers = update_entry(headers, exif_index, modification_date_index, modification_date)

    {headers, exif_block_index} = ensure_exif_block(headers, exif_index)

    # Date Time Original
    {headers, date_time_index} =
      ensure_exif_block_entry(headers, exif_index, exif_block_index, :date_time_original)

    date_time_original = Entry.new_by_type(:date_time_original, date_time_text)

    headers =
      update_exif_block_entry(
        headers,
        exif_index,
        exif_block_index,
        date_time_index,
        date_time_original
      )

    # Create Date
    {headers, create_date_index} =
      ensure_exif_block_entry(headers, exif_index, exif_block_index, :create_date)

    create_date = Entry.new_by_type(:create_date, date_time_text)

    headers =
      update_exif_block_entry(
        headers,
        exif_index,
        exif_block_index,
        create_date_index,
        create_date
      )
      |> IO.inspect(label: "headers")

    {:ok, headers, remainder}
  end

  def set_gps(%{} = input, %GPS{} = gps) do
    Logger.info("Exiffer.Rewrite.set_gps/2")
    {jpeg, remainder} = Exiffer.parse(input)

    Logger.debug("Adding/updating GPS entry")
    {headers, exif_index} = ensure_exif(jpeg.headers)
    {headers, gps_index} = ensure_entry(headers, exif_index, :gps_info)
    entry = build_gps_entry(gps)
    headers = update_entry(headers, exif_index, gps_index, entry)

    {:ok, headers, remainder}
  end

  ###################
  # Top-level APP1 EXIF block

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

  ###################
  # APP1 EXIF IFD entries

  defp ensure_entry(headers, exif_index, type) do
    index = entry_index(headers, exif_index, type)

    if index do
      {headers, index}
    else
      headers =
        headers
        |> update_in(
          ifd_entries_path(exif_index),
          fn entries -> [Entry.new_by_type(type, nil) | entries] end
        )

      {headers, 0}
    end
  end

  defp update_entry(headers, exif_index, entry_index, entry) do
    headers
    |> update_in(
      ifd_entries_path(exif_index) ++ [Access.at(entry_index)],
      fn _existing -> entry end
    )
  end

  defp entry_index(headers, exif_index, type) do
    entries = ifd_entries(headers, exif_index)
    Enum.find_index(entries, fn ifd -> ifd.type == type end)
  end

  defp ifd_entries(headers, exif_index) do
    get_in(headers, ifd_entries_path(exif_index))
  end

  # We assume there is only one IFD in the EXIF block
  defp ifd_entries_path(exif_index) do
    [
      Access.at(exif_index),
      Access.key(:ifd_block),
      Access.key(:ifds),
      Access.at(0),
      Access.key(:entries)
    ]
  end

  ###################
  # APP1 EXIF IFD 'EXIF OFFSET' entry IFD entries

  defp ensure_exif_block(headers, exif_index) do
    index = entry_index(headers, exif_index, :exif_offset)

    if index do
      {headers, index}
    else
      headers =
        headers
        |> update_in(
          ifd_entries_path(exif_index),
          fn entries -> [Entry.new_by_type(:exif_offset, %IFD{}) | entries] end
        )

      {headers, 0}
    end
  end

  defp ensure_exif_block_entry(headers, exif_index, exif_block_index, type) do
    index = exif_block_entry_index(headers, exif_index, exif_block_index, type)

    if index do
      {headers, index}
    else
      headers =
        headers
        |> update_in(
          exif_block_entries_path(exif_index, exif_block_index),
          fn entries -> [Entry.new_by_type(type, nil) | entries] end
        )

      {headers, 0}
    end
  end

  defp update_exif_block_entry(headers, exif_index, exif_block_index, entry_index, entry) do
    headers
    |> update_in(
      exif_block_entries_path(exif_index, exif_block_index) ++ [Access.at(entry_index)],
      fn _existing -> entry end
    )
  end

  defp exif_block_entry_index(headers, exif_index, exif_block_index, type) do
    entries = exif_block_entries(headers, exif_index, exif_block_index)
    Enum.find_index(entries, fn ifd -> ifd.type == type end)
  end

  defp exif_block_entries(headers, exif_index, exif_block_index) do
    get_in(headers, exif_block_entries_path(exif_index, exif_block_index))
  end

  defp exif_block_entries_path(exif_index, exif_block_index) do
    ifd_entries_path(exif_index) ++
      [
        Access.at(exif_block_index),
        Access.key(:value),
        Access.key(:entries)
      ]
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
