defmodule Exiffer.JPEG.IFD do
  @moduledoc """
  Documentation for `Exiffer.JPEG.IFD`.
  """

  require Logger

  alias Exiffer.Binary
  alias Exiffer.JPEG.Entry
  import Exiffer.Logging, only: [integer: 1]

  defstruct entries: []

  defimpl Jason.Encoder do
    alias Exiffer.JPEG.IFD

    @spec encode(%IFD{}, Jason.Encode.opts()) :: String.t()
    def encode(ifd, opts) do
      Jason.Encode.map(
        %{
          module: "Exiffer.JPEG.IFD",
          entries: IFD.sorted(ifd.entries)
        },
        opts
      )
    end
  end

  def read(%{} = buffer, opts \\ []) do
    {entry_count_bytes, buffer} = Exiffer.Buffer.consume(buffer, 2)
    entry_count = Binary.to_integer(entry_count_bytes)
    Logger.debug("IFD reading #{integer(entry_count)} entries")
    {entries, buffer} = read_entry(buffer, entry_count, [], opts)
    Logger.debug("IFD read #{length(entries)} entries")
    entries = sorted(entries)
    ifd = %__MODULE__{entries: entries}
    read_entries = length(entries)

    if read_entries == entry_count do
      {:ok, ifd, buffer}
    else
      Logger.debug(
        "IFD.read returning error as #{read_entries} entries were found, expected #{entry_count}"
      )

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

    {end_of_block, headers, extras} =
      entries
      |> sorted()
      |> Enum.reduce(
        {next_ifd_pointer_offset + 4, [], []},
        fn entry, {end_of_block, headers, extras} ->
          format = Entry.format_name(entry)
          content = Entry.text(entry)
          Logger.debug("Creating binary for #{format} Entry, value: #{inspect(content)}")
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

    <<count_binary::binary, headers_binary::binary, next_ifd_binary::binary,
      extras_binary::binary>>
  end

  def text(%__MODULE__{entries: entries}) do
    entries
    |> sorted()
    |> Enum.flat_map(&Entry.text(&1))
    |> texts()
    |> Enum.join("\n")
  end

  defp texts([]), do: []

  defp texts(texts) do
    longest_label =
      texts
      |> Enum.map(fn {key, _value} -> String.length(key) end)
      |> Enum.max()

    texts
    |> Enum.map(fn {label, value} ->
      if value do
        start = String.pad_trailing("#{label}:", longest_label + 2)

        rest =
          try do
            "#{value}"
          rescue
            _e ->
              "???"
          end
        "#{start} #{rest}"
      else
        # If there's no label, it's a subtitle
        "#{label}\n#{String.duplicate("-", String.length(label))}"
      end
    end)
  end

  defp read_entry(buffer, 0, entries, _opts) do
    Logger.debug("Loading thumbnail, if specified")
    load_thumbnail(buffer, entries)
  end

  defp read_entry(%{} = buffer, count, entries, opts) do
    nth = length(entries)
    position = Exiffer.Buffer.tell(buffer)
    offset = buffer.offset

    Logger.debug(
      "Reading Entry #{nth} at buffer position #{integer(position)}, (absolute #{integer(offset + position)})"
    )

    {entry, buffer} = Entry.new(buffer, opts)

    if entry do
      format = Entry.format_name(entry)
      content = Entry.text(entry)
      Logger.debug("#{format} Entry #{nth} read: #{inspect(content)}")

      read_entry(buffer, count - 1, [entry | entries], opts)
    else
      Logger.debug("Entry #{nth} not read")
      read_entry(buffer, 0, entries, opts)
    end
  end

  defp load_thumbnail(%{} = buffer, entries) do
    case thumbnail_entries(entries) do
      {thumbnail_offset, thumbnail_length} ->
        thumbnail = Exiffer.Buffer.random(buffer, thumbnail_offset, thumbnail_length)
        # Replace thumbnail offset with the thumbnail binary
        entries =
          Enum.map(entries, fn entry ->
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

  def sorted(entries) do
    Enum.sort(entries, &(&1.magic < &2.magic))
  end

  def dimensions(%__MODULE__{entries: entries}) do
    entries
    |> Enum.reduce(%{}, fn entry, dimensions ->
      case entry.type do
        :exif_image_width -> Map.put(dimensions, :width, entry.value)
        :exif_image_height -> Map.put(dimensions, :height, entry.value)
        _ -> dimensions
      end
    end)
    |> then(& if Kernel.map_size(&1) == 2, do: &1, else: nil)
  end
end
