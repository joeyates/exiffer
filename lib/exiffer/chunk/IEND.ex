defmodule Exiffer.Chunk.IEND do
  defstruct []

  def binary(_iend) do
    Exiffer.Chunk.binary("IEND", <<>>)
  end

  def puts(_iend) do
    IO.puts """
    IEND
    ----
    """
  end

  def write(item, io_device) do
    binary = binary(item)
    :ok = IO.binwrite(io_device, binary)
  end

  defimpl Exiffer.Serialize do
    alias Exiffer.Chunk.IEND

    def binary(iend) do
      IEND.binary(iend)
    end

    def puts(iend) do
      IEND.puts(iend)
    end

    def write(iend, io_device) do
      IEND.write(iend, io_device)
    end
  end
end
