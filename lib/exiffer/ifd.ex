defmodule Exiffer.IFD do
  @moduledoc """
  Documentation for `Exiffer.IFD`.
  """

  alias Exiffer.Binary
  alias Exiffer.Entry
  alias Exiffer.OffsetBuffer
  require Logger

  @enforce_keys ~w(entries)a
  defstruct ~w(entries)a

  def read(%OffsetBuffer{} = buffer) do
    {<<entry_count_bytes::binary-size(2)>>, buffer} = OffsetBuffer.consume(buffer, 2)
    entry_count = Binary.to_integer(entry_count_bytes)
    Logger.debug "IFD reading #{entry_count} entries"
    {entries, buffer} = read_entry(buffer, entry_count, [])
    ifd = %__MODULE__{entries: Enum.reverse(entries)}
    {ifd, buffer}
  end

  @doc """
  Returns a binary representation of the IFD block.

  Serializing IFDs is messy, as they need to "know" the offsets
  of their own "extra data" (strings and other data that doesn't fit inside 4 bytes)
  and also the offset of any following IFD block.
  """
  def binary(%__MODULE__{entries: entries}, offset, opts \\ []) do
    is_last = Keyword.get(opts, :is_last, true)
    count = length(entries)
    next_ifd_pointer_offset = offset + 2 + count * 12
    {end_of_block, headers, extras} = Enum.reduce(
      entries,
      {next_ifd_pointer_offset + 4, [], []},
      fn entry, {end_of_block, headers, extras} ->
        {header, extra} = Entry.binary(entry, end_of_block)
        {
          end_of_block + byte_size(extra),
          [header | headers],
          [extra | extras]
        }
      end
    )
    count_binary = Binary.int16u_to_current(count)
    headers_binary = headers |> Enum.reverse() |> Enum.join()
    next_ifd_offset = if is_last, do: 0, else: end_of_block
    next_ifd_binary = Binary.int32u_to_current(next_ifd_offset)
    extras_binary = extras |> Enum.reverse() |> Enum.join()
    <<count_binary::binary, headers_binary::binary, next_ifd_binary::binary, extras_binary::binary>>
  end

  defp read_entry(buffer, 0, entries) do
    load_thumbnail(buffer, entries)
  end

  defp read_entry(%OffsetBuffer{} = buffer, count, entries) do
    position = OffsetBuffer.tell(buffer)
    offset = buffer.offset
    {entry, buffer} = Entry.new(buffer)
    format = Entry.format_name(entry)
    Logger.debug "Entry #{count}, '#{entry.type}' (#{format}) at 0x#{Integer.to_string(position, 16)}, offset 0x#{Integer.to_string(offset, 16)}"

    read_entry(buffer, count - 1, [entry | entries])
  end

  defp load_thumbnail(%OffsetBuffer{} = buffer, entries) do
    case thumbnail_entries(entries) do
      {thumbnail_offset, thumbnail_length} ->
        thumbnail = OffsetBuffer.random(buffer, thumbnail_offset, thumbnail_length)
        # Replace thumbnail offset with the thumbnail binary
        entries = Enum.map(entries, fn entry ->
          if entry.type == :thumbnail_offset do
            struct!(entry, value: thumbnail)
          else
            entry
          end
        end)
        {entries, buffer}
      _ ->
        {entries, buffer}
    end
  end

  defp thumbnail_entries(entries) do
    thumbnail_offset = find_entry_value(entries, :thumbnail_offset)
    thumbnail_length = find_entry_value(entries, :thumbnail_length)
    if thumbnail_offset && thumbnail_length do
      {thumbnail_offset, thumbnail_length}
    end
  end

  defp find_entry_value(entries, type) do
    case Enum.find(entries, &(&1.type == type)) do
      nil -> nil
      entry -> entry.value
    end
  end
end
