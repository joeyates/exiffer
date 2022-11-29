defmodule Exiffer.IFDBlock do
  @moduledoc """
  Documentation for `Exiffer.IFDBlock`.
  """

  alias Exiffer.Binary
  alias Exiffer.Buffer
  alias Exiffer.IFD
  alias Exiffer.OffsetBuffer
  require Logger

  @enforce_keys ~w(ifds)a
  defstruct ~w(ifds)a

  def new(%Buffer{} = main_buffer, offset) do
    offset_buffer = OffsetBuffer.new(main_buffer, offset)
    {ifds, _offset_buffer} = read(offset_buffer, [])
    ifd_block = %__MODULE__{ifds: Enum.reverse(ifds)}
    {ifd_block, main_buffer}
  end

  @doc """
  Returns a serialized binary of the IFD block
  """
  def binary(%__MODULE__{} = ifd_block) do
    # We assume preceding 4 bytes for the TIFF header
    tiff_header_length = 4
    offset = tiff_header_length + 4
    last_ifd_index = length(ifd_block.ifds) - 1
    {_offset, binary} =
      ifd_block.ifds
      |> Enum.with_index()
      |> Enum.reduce({offset, <<>>}, fn {ifd, i}, {offset, binary} ->
        is_last = i == last_ifd_index
        ifd_binary = IFD.binary(ifd, offset, is_last: is_last)
        offset = offset + byte_size(ifd_binary)
        binary = <<binary::binary, ifd_binary::binary>>
        {offset, binary}
      end)
    binary
  end

  def puts(%__MODULE__{} = ifd_block) do
    ifd_block.ifds
    |> Enum.with_index()
    |> Enum.each(fn {ifd, i} ->
      if i == 1 do
        IO.puts "Thumbnail"
        IO.puts "---------"
      end
      IFD.puts(ifd)
    end)

    :ok
  end

  defp read(%OffsetBuffer{} = buffer, ifds) do
    position = OffsetBuffer.tell(buffer) - 2
    offset = buffer.offset
    Logger.info "IFDBlock.do_read at 0x#{Integer.to_string(position, 16)}, offset 0x#{Integer.to_string(offset, 16)}"
    {ifd, buffer} = IFD.read(buffer)
    {next_ifd_bytes, buffer} = OffsetBuffer.consume(buffer, 4)
    next_ifd = Binary.to_integer(next_ifd_bytes)
    if next_ifd == 0 do
      {[ifd | ifds], buffer}
    else
      Logger.info "IFDBlock.do_read, reading next IFD at 0x#{Integer.to_string(next_ifd, 16)}"
      buffer = OffsetBuffer.seek(buffer, next_ifd)
      read(buffer, [ifd | ifds])
    end
  end
end
