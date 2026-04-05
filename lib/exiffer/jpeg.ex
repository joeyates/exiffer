defmodule Exiffer.JPEG do
  @moduledoc """
  Documentation for `Exiffer.JPEG`.
  """

  import Exiffer.Logging, only: [integer: 1]

  alias Exiffer.Binary
  alias Exiffer.GPS
  alias __MODULE__.Header.{APP1, APP4, COM, Data, EOI, JFIF, Junk, SOF0, SOS, Trailer}
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
  # High-level Manipulation functions

  ###############################
  ## 1. GPS

  def gps_entry(%__MODULE__{} = jpeg) do
    exif_entry(jpeg, :gps_info)
  end

  def has_gps_entry?(%__MODULE__{} = jpeg) do
    has_exif_entry?(jpeg, :gps_info)
  end

  def get_gps(%__MODULE__{} = jpeg) do
    case gps_entry(jpeg) do
      {:ok, entry} -> GPS.from_entry(entry)
      {:error, reason} -> {:error, reason}
    end
  end

  def set_gps(%__MODULE__{} = jpeg, %GPS{} = gps) do
    entry = GPS.to_entry(gps)
    set_exif_field(jpeg, :gps_info, entry.value)
  end

  ###############################
  ## 2. Date/Time

  def get_modification_date(%__MODULE__{} = jpeg) do
    case get_exif_field(jpeg, :modification_date) do
      {:ok, value} -> parse_date_time(value)
      {:error, reason} -> {:error, reason}
    end
  end

  def set_modification_date(%__MODULE__{} = jpeg, %NaiveDateTime{} = date_time) do
    set_exif_field(jpeg, :modification_date, NaiveDateTime.to_string(date_time))
  end

  def get_date_time_original(%__MODULE__{} = jpeg) do
    case get_sub_ifd_field(jpeg, :exif_offset, :date_time_original) do
      {:ok, value} -> parse_date_time(value)
      {:error, reason} -> {:error, reason}
    end
  end

  def set_date_time_original(%__MODULE__{} = jpeg, %NaiveDateTime{} = date_time) do
    set_sub_ifd_field(jpeg, :exif_offset, :date_time_original, NaiveDateTime.to_string(date_time))
  end

  def get_create_date(%__MODULE__{} = jpeg) do
    case get_sub_ifd_field(jpeg, :exif_offset, :create_date) do
      {:ok, value} -> parse_date_time(value)
      {:error, reason} -> {:error, reason}
    end
  end

  def set_create_date(%__MODULE__{} = jpeg, %NaiveDateTime{} = date_time) do
    set_sub_ifd_field(jpeg, :exif_offset, :create_date, NaiveDateTime.to_string(date_time))
  end

  defp parse_date_time(value) when is_binary(value) do
    all_colons_regex = ~r/
      ^
      (?<year>\d{4})
      :
      (?<month>\d{2})
      :
      (?<day>\d{2})
      (\s|T)
      (?<hour>\d{2})
      :
      (?<minute>\d{2})
      :
      (?<second>\d{2})
      $
      /x

    case Regex.run(all_colons_regex, value,
           capture: [:year, :month, :day, :hour, :minute, :second]
         ) do
      nil ->
        NaiveDateTime.from_iso8601(value)

      [year, month, day, hour, minute, second] ->
        # If the value matches the all-colons format, we convert it to ISO8601 format
        iso_value = "#{year}-#{month}-#{day}T#{hour}:#{minute}:#{second}"
        NaiveDateTime.from_iso8601(iso_value)
    end
  end

  def remove_non_standard_headers(%__MODULE{} = jpeg) do
    headers = Enum.filter(jpeg.headers, &(&1.__struct__ != Junk))
    %{jpeg | headers: headers}
  end

  ###################
  # Top-level APP1 EXIF block

  def get_exif_field(%__MODULE__{} = jpeg, name) do
    case exif_entry(jpeg, name) do
      {:ok, entry} -> {:ok, entry.value}
      {:error, reason} -> {:error, reason}
    end
  end

  def set_exif_field(%__MODULE__{headers: headers} = jpeg, name, value) do
    {headers, exif_index, entry_index} = ensure_exif_entry(headers, name)
    entry = Entry.new_by_type(name, value)
    headers = update_exif_entry(headers, exif_index, entry_index, entry)
    %{jpeg | headers: headers}
  end

  def exif_index(%__MODULE__{} = jpeg) do
    exif_index(jpeg.headers)
  end

  def exif_index(headers) when is_list(headers) do
    Enum.find_index(headers, &is_struct(&1, EXIF))
  end

  defp ensure_exif([]), do: {default_exif(), 0}

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
  # Top-level APP1 EXIF block's entries

  def exif_entry(%__MODULE__{headers: headers} = jpeg, type) when is_atom(type) do
    case exif_entry_path(jpeg, type) do
      {:ok, path} ->
        {:ok, get_in(headers, path)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def has_exif_entry?(%__MODULE__{headers: headers}, type) when is_atom(type) do
    with exif_index when not is_nil(exif_index) <- exif_index(headers),
         entry_index when not is_nil(entry_index) <- exif_entry_index(headers, exif_index, type) do
      true
    else
      _ ->
        false
    end
  end

  defp exif_entry_path(%__MODULE__{headers: headers}, type) when is_atom(type) do
    with exif_index when not is_nil(exif_index) <- exif_index(headers),
         entry_index when not is_nil(entry_index) <-
           exif_entry_index(headers, exif_index, type) do
      {:ok, exif_ifd_entries_path(exif_index) ++ [Access.at(entry_index)]}
    else
      _ ->
        {:error, "EXIF entry ':#{type}' not found"}
    end
  end

  defp exif_entry_index(headers, exif_index, type) do
    entries = exif_ifd_entries(headers, exif_index)
    Enum.find_index(entries, fn ifd -> ifd.type == type end)
  end

  defp exif_ifd_entries(headers, exif_index) do
    get_in(headers, exif_ifd_entries_path(exif_index))
  end

  # We assume there is only one IFD in the EXIF block
  defp exif_ifd_entries_path(exif_index) do
    [
      Access.at(exif_index),
      Access.key(:ifd_block),
      Access.key(:ifds),
      Access.at(0),
      Access.key(:entries)
    ]
  end

  defp ensure_exif_entry(headers, name) do
    {headers, exif_index} = ensure_exif(headers)
    {headers, entry_index} = ensure_exif_entry(headers, exif_index, name)
    {headers, exif_index, entry_index}
  end

  defp ensure_exif_entry(headers, exif_index, type) do
    index = exif_entry_index(headers, exif_index, type)

    if index do
      {headers, index}
    else
      headers =
        update_in(
          headers,
          exif_ifd_entries_path(exif_index),
          fn entries -> [Entry.new_by_type(type, nil) | entries] end
        )

      {headers, 0}
    end
  end

  defp update_exif_entry(headers, exif_index, entry_index, entry) do
    update_in(
      headers,
      exif_ifd_entries_path(exif_index) ++ [Access.at(entry_index)],
      fn _existing -> entry end
    )
  end

  ###################
  # APP1 EXIF SUB IFD entries

  def get_sub_ifd_field(%__MODULE__{} = jpeg, block, name) do
    sub_ifd_field(jpeg, block, name)
  end

  def set_sub_ifd_field(%__MODULE__{headers: headers} = jpeg, block, name, value) do
    {headers, exif_index} = ensure_exif(headers)
    {headers, block_entry_index} = ensure_sub_ifd_block(headers, exif_index, block)

    {headers, entry_index} =
      ensure_sub_ifd_block_entry(headers, exif_index, block_entry_index, name)

    entry = Entry.new_by_type(name, value)

    headers =
      update_sub_ifd_block_entry(headers, exif_index, block_entry_index, entry_index, entry)

    %{jpeg | headers: headers}
  end

  def sub_ifd_field(%__MODULE__{} = jpeg, block, name) do
    case sub_ifd_entry(jpeg, block, name) do
      {:ok, entry} -> {:ok, entry.value}
      {:error, reason} -> {:error, reason}
    end
  end

  def sub_ifd_entry(%__MODULE__{headers: headers}, block, type) when is_atom(type) do
    case sub_ifd_entry_path(%__MODULE__{headers: headers}, block, type) do
      {:ok, path} ->
        {:ok, get_in(headers, path)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp sub_ifd_entry_path(%__MODULE__{} = jpeg, block, type) when is_atom(type) do
    with {:ok, sub_ifd_entries} <- sub_ifd_entries(jpeg, block),
         entry_index when not is_nil(entry_index) <-
           Enum.find_index(sub_ifd_entries, fn ifd -> ifd.type == type end) do
      {:ok, sub_ifd_path} = sub_ifd_path(jpeg, block)
      {:ok, sub_ifd_path ++ [Access.at(entry_index)]}
    else
      _ ->
        {:error, "EXIF subblock ':#{block}' entry '#{type}' not found"}
    end
  end

  defp ensure_sub_ifd_block(headers, exif_index, block) do
    index = exif_entry_index(headers, exif_index, block)

    if index do
      {headers, index}
    else
      block_entry = Entry.new_by_type(block, %IFD{entries: []})

      headers =
        update_in(headers, exif_ifd_entries_path(exif_index), fn entries ->
          [block_entry | entries]
        end)

      {headers, 0}
    end
  end

  defp ensure_sub_ifd_block_entry(headers, exif_index, block_entry_index, type) do
    path = sub_ifd_block_entries_path(exif_index, block_entry_index)
    entries = get_in(headers, path) || []
    index = Enum.find_index(entries, fn e -> e.type == type end)

    if index do
      {headers, index}
    else
      headers =
        update_in(headers, path, fn entries ->
          [Entry.new_by_type(type, nil) | entries || []]
        end)

      {headers, 0}
    end
  end

  defp sub_ifd_block_entries_path(exif_index, block_entry_index) do
    exif_ifd_entries_path(exif_index) ++
      [
        Access.at(block_entry_index),
        Access.key(:value),
        Access.key(:entries)
      ]
  end

  defp update_sub_ifd_block_entry(headers, exif_index, block_entry_index, entry_index, entry) do
    update_in(
      headers,
      sub_ifd_block_entries_path(exif_index, block_entry_index) ++ [Access.at(entry_index)],
      fn _existing -> entry end
    )
  end

  defp sub_ifd_entries(%__MODULE__{headers: headers}, block) do
    case sub_ifd_path(%__MODULE__{headers: headers}, block) do
      {:ok, path} ->
        {:ok, get_in(headers, path)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp sub_ifd_path(%__MODULE__{headers: headers}, block) do
    with exif_index when not is_nil(exif_index) <- exif_index(headers),
         sub_ifd_entry_index when not is_nil(sub_ifd_entry_index) <-
           exif_entry_index(headers, exif_index, block) do
      {:ok,
       exif_ifd_entries_path(exif_index) ++
         [
           Access.at(sub_ifd_entry_index),
           Access.key(:value),
           Access.key(:entries)
         ]}
    else
      _ ->
        {:error, "EXIF subblock ':#{block}' not found"}
    end
  end

  #################################
  # Header parsing functions

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
