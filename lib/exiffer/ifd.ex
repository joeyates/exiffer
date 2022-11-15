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
    ifd_count = Binary.to_integer(ifd_count_bytes)
    Logger.debug "IFD reading #{ifd_count} entries"
    {ifd_entries, buffer} = read_entry(buffer, ifd_count, [])
    ifd = %{
      type: "IFD",
      entries: Enum.reverse(ifd_entries)
    }
    {ifd, buffer}
  end

  def read_entry(buffer, 0, ifd_entries) do
    {ifd_entries, buffer}
  end

  def read_entry(%OffsetBuffer{} = buffer, count, ifd_entries) do
    position = OffsetBuffer.tell(buffer)
    offset = buffer.offset
    {entry, buffer} = Entry.new(buffer)
    format = Entry.format_name(entry)
    Logger.debug "Entry #{count}, '#{entry.type}' (#{format}) at 0x#{Integer.to_string(position, 16)}, offset 0x#{Integer.to_string(offset, 16)}"

    read_entry(buffer, count - 1, [entry | ifd_entries])
  end
end
