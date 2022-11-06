defmodule Exiffer.IFDs do
  @moduledoc """
  Documentation for `Exiffer.IFDs`.
  """

  import Exiffer.Binary, only: [little_endian_to_decimal: 1]
  import Exiffer.OffsetBuffer, only: [consume: 2, random: 3, seek: 2]

  def read(%Exiffer.Buffer{} = main_buffer, offset) do
    {_offset_buffer, ifds} =
      Exiffer.OffsetBuffer.new(main_buffer, offset)
      |> do_read([])
    ifds
  end

  def read_thumbnail(%Exiffer.Buffer{} = main_buffer, offset, ifds) do
    offset_buffer = Exiffer.OffsetBuffer.new(main_buffer, offset)
    case thumbnail_entries(ifds) do
      {thumbnail_offset, thumbnail_length} ->
        {thumbnail, _offset_buffer} = random(offset_buffer, thumbnail_offset, thumbnail_length)
        thumbnail
      _ ->
        nil
    end
  end

  defp do_read(%Exiffer.OffsetBuffer{} = buffer, ifds) do
    {buffer, ifd} = Exiffer.IFD.read(buffer)
    {next_ifd_bytes, buffer} = consume(buffer, 4)
    next_ifd = little_endian_to_decimal(next_ifd_bytes)
    if next_ifd == 0 do
      {buffer, [ifd | ifds]}
    else
      buffer = seek(buffer, next_ifd)
      do_read(buffer, [ifd | ifds])
    end
  end

  defp thumbnail_entries(ifds) when is_list(ifds) do
    Enum.find_value(ifds, &(thumbnail_entries(&1)))
  end

  defp thumbnail_entries(ifd) when is_map(ifd) do
    offset_entry = Enum.find(ifd.entries, &(&1.type == "ThumbnailOffset"))
    length_entry = Enum.find(ifd.entries, &(&1.type == "ThumbnailLength"))
    if offset_entry && length_entry do
      {offset_entry.value, length_entry.value}
    else
      nil
    end
  end
end
