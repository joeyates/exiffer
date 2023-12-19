defmodule Exiffer.JPEG.IFDBlock do
  @moduledoc """
  Documentation for `Exiffer.JPEG.IFDBlock`.
  """

  require Logger

  alias Exiffer.Binary
  alias Exiffer.JPEG.IFD

  @enforce_keys ~w(ifds)a
  defstruct ~w(ifds)a

  defimpl Jason.Encoder  do
    @spec encode(%Exiffer.JPEG.IFDBlock{}, Jason.Encode.opts()) :: String.t()
    def encode(entry, opts) do
      Jason.Encode.map(
        %{
          module: "Exiffer.JPEG.IFDBlock",
          ifds: entry.ifds
        },
        opts
      )
    end
  end

  def new(%{} = main_buffer, offset) do
    offset_buffer = Exiffer.Buffer.offset_buffer(main_buffer, offset)
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

  def text(%__MODULE__{} = ifd_block) do
    ifd_block.ifds
    |> Enum.with_index()
    |> Enum.map(fn {ifd, i} ->
      if i == 1 do
        """
        Thumbnail
        ---------
        """ <> IFD.text(ifd)
      else
        IFD.text(ifd)
      end
    end)
    |> Enum.join("\n")
  end

  defp read(%{} = buffer, ifds) do
    position = Exiffer.Buffer.tell(buffer) - 2
    offset = buffer.offset
    Logger.debug "IFDBlock.do_read at 0x#{Integer.to_string(position, 16)}, offset 0x#{Integer.to_string(offset, 16)}"
    case IFD.read(buffer) do
      {:ok, ifd, buffer} ->
        {next_ifd_bytes, buffer} = Exiffer.Buffer.consume(buffer, 4)
        next_ifd = Binary.to_integer(next_ifd_bytes)
        if next_ifd == 0 do
          {[ifd | ifds], buffer}
        else
          Logger.debug "IFDBlock.do_read, reading next IFD at 0x#{Integer.to_string(next_ifd, 16)}"
          buffer = Exiffer.Buffer.seek(buffer, next_ifd)
          read(buffer, [ifd | ifds])
        end
      {:error, ifd, buffer} ->
        {[ifd | ifds], buffer}
    end
  end
end
