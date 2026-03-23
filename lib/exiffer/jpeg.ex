defmodule Exiffer.JPEG do
  @moduledoc """
  Documentation for `Exiffer.JPEG`.
  """

  import Exiffer.Logging, only: [integer: 1]

  alias Exiffer.Binary
  alias Exiffer.GPS
  alias __MODULE__.Header.{APP1, APP4, COM, Data, EOI, JFIF, SOF0, SOS, Trailer}
  alias __MODULE__.Header.APP1.EXIF
  alias __MODULE__.Entry
  alias __MODULE__.IFD
  alias __MODULE__.IFDBlock

  require Logger

  @enforce_keys ~w(headers)a
  defstruct ~w(headers)a

  @magic <<0xFF, 0xD8>>

  def magic(), do: @magic

  def new(%{data: <<@magic, _rest::binary>>} = buffer) do
    buffer = Exiffer.Buffer.skip(buffer, 2)
    Logger.debug("#{__MODULE__}.new/1 - setting initial byte order to :big")
    Binary.set_byte_order(:big)
    {%{} = buffer, headers} = headers(buffer, [])
    {%__MODULE__{headers: Enum.reverse(headers)}, buffer}
  end

  def binary(%__MODULE__{} = jpeg) do
    Logger.debug("#{__MODULE__} creating binary")
    Exiffer.Serialize.binary(jpeg.headers)
  end

  def text(%__MODULE__{} = jpeg) do
    Exiffer.Serialize.text(jpeg.headers)
  end

  def write(%__MODULE__{} = jpeg, io_device) do
    Logger.debug("#{__MODULE__} writing binary")
    :ok = IO.binwrite(io_device, @magic)
    :ok = Exiffer.Serialize.write(jpeg.headers, io_device)
  end

  ###############################
  # Manipulation functions

  def set_field(%__MODULE__{headers: headers} = jpeg, name, value) do
    Logger.debug("Adding/updating :#{name} field to '#{value}'")
    {headers, exif_index, entry_index} = ensure_exif_entry(headers, name)
    entry = Entry.new_by_type(name, value)
    headers = update_entry(headers, exif_index, entry_index, entry)
    %{jpeg | headers: headers}
  end

  def set_date_time(%__MODULE__{headers: headers} = jpeg, %NaiveDateTime{} = date_time) do
    date_time_text = NaiveDateTime.to_string(date_time)

    Logger.debug("Adding/updating date/time")
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

    headers =
      update_exif_block_entry(
        headers,
        exif_index,
        exif_block_index,
        create_date_index,
        create_date
      )

    %{jpeg | headers: headers}
  end

  def set_gps(%__MODULE__{headers: headers} = jpeg, %GPS{} = gps) do
    {headers, exif_index} = ensure_exif(headers)
    {headers, gps_index} = ensure_entry(headers, exif_index, :gps_info)
    entry = GPS.to_entry(gps)
    headers = update_entry(headers, exif_index, gps_index, entry)
    %{jpeg | headers: headers}
  end

  defp ensure_exif_entry(headers, name) do
    {headers, exif_index} = ensure_exif(headers)
    {headers, entry_index} = ensure_entry(headers, exif_index, name)
    {headers, exif_index, entry_index}
  end

  ###############################
  # Access functions

  def entry_path(%__MODULE__{headers: headers}, type) when is_atom(type) do
    with exif_index when not is_nil(exif_index) <- exif_index(headers),
         entry_index when not is_nil(entry_index) <- entry_index(headers, exif_index, type) do
      {:ok, ifd_entries_path(exif_index) ++ [Access.at(entry_index)]}
    else
      _ ->
        {:error, "EXIF entry ':#{type}' not found"}
    end
  end

  def has_entry?(%__MODULE__{headers: headers}, type) when is_atom(type) do
    with exif_index when not is_nil(exif_index) <- exif_index(headers),
         entry_index when not is_nil(entry_index) <- entry_index(headers, exif_index, type) do
      true
    else
      _ ->
        false
    end
  end

  def entry(%__MODULE__{headers: headers} = jpeg, type) when is_atom(type) do
    case entry_path(jpeg, type) do
      {:ok, path} ->
        {:ok, get_in(headers, path)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # GPS-specific

  def gps_entry(%__MODULE__{} = jpeg) do
    entry(jpeg, :gps_info)
  end

  def has_gps_entry?(%__MODULE__{} = jpeg) do
    has_entry?(jpeg, :gps_info)
  end

  def gps_entry_path(%__MODULE__{} = jpeg) do
    entry_path(jpeg, :gps_info)
  end

  ###################
  # Top-level APP1 EXIF block

  def exif_index(headers) do
    Enum.find_index(headers, &is_struct(&1, EXIF))
  end

  defp ensure_exif(headers) do
    index = exif_index(headers)

    if index do
      {headers, index}
    else
      {List.insert_at(headers, 1, default_exif()), 1}
    end
  end

  defp default_exif() do
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

  def entry_index(headers, exif_index, type) do
    entries = ifd_entries(headers, exif_index)
    Enum.find_index(entries, fn ifd -> ifd.type == type end)
  end

  defp ensure_entry(headers, exif_index, type) do
    index = entry_index(headers, exif_index, type)

    if index do
      {headers, index}
    else
      headers =
        update_in(
          headers,
          ifd_entries_path(exif_index),
          fn entries -> [Entry.new_by_type(type, nil) | entries] end
        )

      {headers, 0}
    end
  end

  defp update_entry(headers, exif_index, entry_index, entry) do
    update_in(
      headers,
      ifd_entries_path(exif_index) ++ [Access.at(entry_index)],
      fn _existing -> entry end
    )
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
        update_in(
          headers,
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
        update_in(
          headers,
          exif_block_entries_path(exif_index, exif_block_index),
          fn entries -> [Entry.new_by_type(type, nil) | entries] end
        )

      {headers, 0}
    end
  end

  defp update_exif_block_entry(headers, exif_index, exif_block_index, entry_index, entry) do
    update_in(
      headers,
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

  defp headers(buffer, headers)

  defp headers(%{data: <<0xFF, 0xD9, _rest::binary>>} = buffer, headers) do
    Logger.debug("Reading EOI header at #{integer(buffer.position)}")
    {:ok, eoi, buffer} = EOI.new(buffer)

    {buffer, headers} =
      if buffer.data == "" do
        {buffer, [eoi | headers]}
      else
        {:ok, trailer, buffer} = Trailer.new(buffer)
        {buffer, [trailer, eoi] ++ headers}
      end

    # Complete recursion
    {buffer, headers}
  end

  defp headers(%{data: <<0xFF, 0xE1, _rest::binary>>} = buffer, headers) do
    Logger.debug("Reading APP1 header at #{integer(buffer.position)}")
    {:ok, app1, buffer} = APP1.new(buffer)
    headers(buffer, [app1 | headers])
  end

  defp headers(%{data: <<0xFF, 0xE4, _rest::binary>>} = buffer, headers) do
    Logger.debug("Reading APP4 header at #{integer(buffer.position)}")
    {:ok, app4, buffer} = APP4.new(buffer)
    headers(buffer, [app4 | headers])
  end

  defp headers(%{data: <<0xFF, 0xFE, _rest::binary>>} = buffer, headers) do
    Logger.debug("Reading COM header at #{integer(buffer.position)}")
    {:ok, comment, buffer} = COM.new(buffer)
    headers(buffer, [comment | headers])
  end

  defp headers(
         %{data: <<0xFF, 0xE0, _length::binary-size(2), "JFIF", 0x00, _rest::binary>>} = buffer,
         headers
       ) do
    Logger.debug("Reading JFIF header at #{integer(buffer.position)}")
    {:ok, jfif, buffer} = JFIF.new(buffer)
    headers(buffer, [jfif | headers])
  end

  defp headers(%{data: <<0xFF, 0xC0, _rest::binary>>} = buffer, headers) do
    Logger.debug("Reading SOF0 header at #{integer(buffer.position)}")
    {:ok, sof0, buffer} = SOF0.new(buffer)
    headers(buffer, [sof0 | headers])
  end

  defp headers(%{data: <<0xFF, 0xDA, _rest::binary>>} = buffer, headers) do
    Logger.debug("Reading SOS header at #{integer(buffer.position)}")
    {:ok, sos, buffer} = SOS.new(buffer)
    headers(buffer, [sos | headers])
  end

  defp headers(%{} = buffer, headers) do
    Logger.debug("Reading generic data header at #{integer(buffer.position)}")
    {:ok, header, buffer} = Data.new(buffer)
    headers(buffer, [header | headers])
  end

  def dimensions(%__MODULE__{} = jpeg) do
    sof0_dimensions(jpeg) || exif_dimensions(jpeg)
  end

  defp sof0_dimensions(%__MODULE__{} = jpeg) do
    case sof0(jpeg) do
      nil -> nil
      sof0 -> SOF0.dimensions(sof0)
    end
  end

  defp exif_dimensions(%__MODULE__{} = jpeg) do
    case exif(jpeg) do
      nil -> nil
      exif -> EXIF.dimensions(exif)
    end
  end

  defp sof0(%__MODULE__{} = jpeg) do
    Enum.find(
      jpeg.headers,
      &(&1.__struct__ == SOF0)
    )
  end

  defp exif(%__MODULE__{} = jpeg) do
    Enum.find(
      jpeg.headers,
      &(&1.__struct__ == EXIF)
    )
  end

  defimpl Jason.Encoder do
    @spec encode(%Exiffer.JPEG{}, Jason.Encode.opts()) :: String.t()
    def encode(entry, opts) do
      Jason.Encode.map(
        %{
          module: "Exiffer.JPEG",
          headers: entry.headers
        },
        opts
      )
    end
  end

  defimpl Exiffer.Serialize do
    def write(%Exiffer.JPEG{} = jpeg, io_device) do
      Exiffer.JPEG.write(jpeg, io_device)
    end

    def binary(jpeg) do
      Exiffer.JPEG.binary(jpeg)
    end

    def text(%Exiffer.JPEG{} = jpeg) do
      Exiffer.JPEG.text(jpeg)
    end
  end
end
