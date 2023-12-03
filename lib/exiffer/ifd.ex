defmodule Exiffer.IFD do
  @moduledoc """
  Documentation for `Exiffer.IFD`.
  """

  require Logger

  alias Exiffer.{Binary, Buffer, Entry}
  import Exiffer.Logging, only: [integer: 1]

  @enforce_keys ~w(entries)a
  defstruct ~w(entries)a

  def read(%{} = buffer, opts \\ []) do
    {entry_count_bytes, buffer} = Buffer.consume(buffer, 2)
    entry_count = Binary.to_integer(entry_count_bytes)
    Logger.debug "IFD reading #{integer(entry_count)} entries"
    {entries, buffer} = read_entry(buffer, entry_count, [], opts)
    ifd = %__MODULE__{entries: Enum.reverse(entries)}
    read_entries = length(entries)
    if read_entries == entry_count do
      {:ok, ifd, buffer}
    else
      {:error, ifd, buffer}
    end
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
        format = Entry.format_name(entry)
        content = Entry.text(entry)
        Logger.debug "Creating binary for #{format} Entry, value: #{inspect(content)}"
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

  def puts(%__MODULE__{} = ifd) do
    ifd.entries
    |> Enum.flat_map(&(Entry.text(&1)))
    |> puts_texts()
  end

  defp puts_texts([]), do: :ok

  defp puts_texts(texts) do
    longest_label =
      texts
      |> Enum.map(fn {key, _value} -> String.length(key) end)
      |> Enum.max()

    texts
    |> Enum.each(fn {label, value} ->
      if value do
        IO.write String.pad_trailing("#{label}:", longest_label + 2)
        try do
          IO.puts value
        rescue _e ->
          IO.puts "???"
        end
      else
        # If there's no label, it's a subtitle
        IO.puts label
        IO.puts String.duplicate("-", String.length(label))
      end
    end)

    :ok
  end

  defp read_entry(buffer, 0, entries, _opts) do
    load_thumbnail(buffer, entries)
  end

  defp read_entry(%{} = buffer, count, entries, opts) do
    position = Buffer.tell(buffer)
    offset = buffer.offset
    {entry, buffer} = Entry.new(buffer, opts)
    if entry do
      format = Entry.format_name(entry)
      content = Entry.text(entry)
      Logger.debug "Reading Entry #{count}, #{format} at 0x#{Integer.to_string(position, 16)}, offset 0x#{Integer.to_string(offset, 16)}, value: #{inspect(content)}"

      read_entry(buffer, count - 1, [entry | entries], opts)
    else
      Logger.debug "Entry #{count} not read"
      read_entry(buffer, 0, entries, opts)
    end
  end

  defp load_thumbnail(%{} = buffer, entries) do
    case thumbnail_entries(entries) do
      {thumbnail_offset, thumbnail_length} ->
        thumbnail = Buffer.random(buffer, thumbnail_offset, thumbnail_length)
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
