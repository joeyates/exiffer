defmodule Exiffer.IFD do
  @moduledoc """
  Documentation for `Exiffer.IFD`.
  """

  alias Exiffer.Binary
  alias Exiffer.Entry
  alias Exiffer.OffsetBuffer
  require Logger

  def read(%OffsetBuffer{} = buffer) do
    {<<ifd_count_bytes::binary-size(2)>>, buffer} = OffsetBuffer.consume(buffer, 2)
    ifd_count = Binary.little_endian_to_integer(ifd_count_bytes)
    {buffer, ifd_entries} = read_entry(buffer, ifd_count, [])
    ifd = %{
      type: "IFD",
      entries: Enum.reverse(ifd_entries),
      count: ifd_count
    }
    {buffer, ifd}
  end

  def read_entry(buffer, 0, ifd_entries) do
    {buffer, ifd_entries}
  end

  def read_entry(%OffsetBuffer{} = buffer, count, ifd_entries) do
    {entry, buffer} = Entry.new(buffer)
    format = Entry.format_name(entry)
    Logger.debug "Entry #{count}, '#{entry.type}' (#{format}) at #{Integer.to_string(buffer.buffer.position, 16)}"

    read_entry(buffer, count - 1, [entry | ifd_entries])
  end
end
