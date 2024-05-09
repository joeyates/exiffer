defmodule Exiffer.Rewrite do
  @moduledoc """
  Rewrite an image file, adding and removing arbitrary metadata
  """

  require Logger

  alias Exiffer.{Binary, GPS, JPEG}
  alias Exiffer.IO.Buffer
  alias Exiffer.JPEG.{Entry, IFD, IFDBlock}
  alias Exiffer.JPEG.Header.APP1.EXIF

  def rewrite(source, destination, rewrite_fun) when is_function(rewrite_fun, 1) do
    input = Buffer.new(source)
    {jpeg, input} = Exiffer.parse(input)

    headers = rewrite_fun.(jpeg.headers)

    Binary.set_byte_order(:big)
    output = Buffer.new(destination, direction: :write)
    Buffer.write(output, JPEG.magic())

    :ok = Exiffer.Serialize.write(headers, output.io_device)
    :ok = Buffer.close(input)
    :ok = Buffer.close(output)

    :ok
  end

  def set_make_and_model(source, destination, make, model) do
    Logger.info("Exiffer.Rewrite.set_make_and_model/4")
    rewrite(source, destination, &internal_set_make_and_model(&1, make, model))
  end

  defp internal_set_make_and_model(headers, make, model) do
    Logger.debug("Adding/updating make & model original entry")
    {headers, exif_index} = ensure_exif(headers)

    # update make
    {headers, make_index} = ensure_entry(headers, exif_index, :make)
    make = Entry.new_by_type(:make, make)
    headers = update_entry(headers, exif_index, make_index, make)

    # update model
    {headers, model_index} = ensure_entry(headers, exif_index, :model)
    model = Entry.new_by_type(:model, model)
    update_entry(headers, exif_index, model_index, model)
  end

  def set_date_time(source, destination, %DateTime{} = date_time) do
    set_date_time(source, destination, DateTime.to_naive(date_time))
  end

  def set_date_time(source, destination, %NaiveDateTime{} = date_time) do
    Logger.info("Exiffer.Rewrite.set_date_time/3")
    rewrite(source, destination, &internal_set_date_time(&1, date_time))
  end

  def set_date_time(%JPEG{} = jpeg, %NaiveDateTime{} = date_time) do
    internal_set_date_time(jpeg.headers, date_time)
  end

  defp internal_set_date_time(headers, date_time) do
    date_time_text = NaiveDateTime.to_string(date_time)

    Logger.debug("Adding/updating date/time original entry")
    {headers, exif_index} = ensure_exif(headers)

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

    update_exif_block_entry(
      headers,
      exif_index,
      exif_block_index,
      create_date_index,
      create_date
    )
  end

  def set_gps(source, destination, %GPS{} = gps) do
    Logger.info("Exiffer.Rewrite.set_gps/2")

    rewrite(source, destination, fn headers ->
      Logger.debug("Adding/updating GPS entry")
      {headers, exif_index} = ensure_exif(headers)
      {headers, gps_index} = ensure_entry(headers, exif_index, :gps_info)
      entry = build_gps_entry(gps)
      update_entry(headers, exif_index, gps_index, entry)
    end)
  end

  def set_gps(%JPEG{} = jpeg, %GPS{} = gps) do
    {headers, exif_index} = ensure_exif(jpeg.headers)
    {headers, gps_index} = ensure_entry(headers, exif_index, :gps_info)
    entry = build_gps_entry(gps)
    update_entry(headers, exif_index, gps_index, entry)
  end

  ###################
  # Top-level APP1 EXIF block

  defp ensure_exif(headers) do
    index = Enum.find_index(headers, fn header -> header.__struct__ == EXIF end)

    if index do
      {headers, index}
    else
      {List.insert_at(headers, 1, default_exif()), 1}
    end
  end

  defp default_exif do
    entries = [
      Entry.new_by_type(:x_resolution, {72, 1}),
      Entry.new_by_type(:y_resolution, {72, 1}),
      Entry.new_by_type(:resolution_unit, 2)
    ]

    %EXIF{
      byte_order: :little,
      ifd_block: %IFDBlock{
        ifds: [%IFD{entries: entries}]
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
