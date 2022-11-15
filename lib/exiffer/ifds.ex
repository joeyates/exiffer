defmodule Exiffer.IFDs do
  @moduledoc """
  Documentation for `Exiffer.IFDs`.
  """

  alias Exiffer.Binary
  alias Exiffer.Buffer
  alias Exiffer.IFD
  alias Exiffer.OffsetBuffer

  def read(%Buffer{} = main_buffer, offset) do
    {_offset_buffer, ifds} =
      OffsetBuffer.new(main_buffer, offset)
      |> do_read([])
    ifds
  end

  def read_thumbnail(%Buffer{} = main_buffer, offset, ifds) do
    case thumbnail_entries(ifds) do
      {thumbnail_offset, thumbnail_length} ->
        {thumbnail, _offset_buffer} =
          OffsetBuffer.new(main_buffer, offset)
          |> OffsetBuffer.random(thumbnail_offset, thumbnail_length)
        {thumbnail, main_buffer}
      _ ->
        {nil, main_buffer}
    end
  end

  def read_ifd(%Buffer{} = main_buffer, offset, ifds, type) do
    case find_value(ifds, type) do
      nil ->
        {nil, main_buffer}
      ifd_offset ->
        buffer = OffsetBuffer.new(main_buffer, offset)
        position = OffsetBuffer.tell(buffer)
        {_buffer, ifd} =
          OffsetBuffer.seek(buffer, ifd_offset)
          |> IFD.read()
        _buffer = OffsetBuffer.seek(buffer, position)
        {ifd, main_buffer}
    end
  end

  defp do_read(%OffsetBuffer{} = buffer, ifds) do
    {buffer, ifd} = IFD.read(buffer)
    {next_ifd_bytes, buffer} = OffsetBuffer.consume(buffer, 4)
    next_ifd = Binary.to_integer(next_ifd_bytes)
    if next_ifd == 0 do
      {buffer, [ifd | ifds]}
    else
      buffer = OffsetBuffer.seek(buffer, next_ifd)
      do_read(buffer, [ifd | ifds])
    end
  end

  defp thumbnail_entries(ifds) do
    thumbnail_offset = find_value(ifds, "ThumbnailOffset")
    thumbnail_length = find_value(ifds, "ThumbnailLength")
    if thumbnail_offset && thumbnail_length do
      {thumbnail_offset, thumbnail_length}
    end
  end

  defp find_value(ifds, type) when is_list(ifds) do
    Enum.find_value(ifds, &(find_value(&1, type)))
  end

  defp find_value(ifd, type) when is_map(ifd) do
    case Enum.find(ifd.entries, &(&1.type == type)) do
      nil -> nil
      entry -> entry.value
    end
  end
end
