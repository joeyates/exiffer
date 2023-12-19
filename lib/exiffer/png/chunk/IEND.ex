defmodule Exiffer.PNG.Chunk.IEND do
  defstruct []

  def binary(_iend) do
    Exiffer.PNG.Chunk.binary("IEND", <<>>)
  end

  def text(_iend) do
    """
    IEND
    ----
    """
  end

  def write(item, io_device) do
    binary = binary(item)
    :ok = IO.binwrite(io_device, binary)
  end

  defimpl Exiffer.Serialize do
    alias Exiffer.PNG.Chunk.IEND

    def binary(iend) do
      IEND.binary(iend)
    end

    def text(iend) do
      IEND.text(iend)
    end

    def write(iend, io_device) do
      IEND.write(iend, io_device)
    end
  end
end
