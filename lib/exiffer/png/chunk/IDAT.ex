defmodule Exiffer.PNG.Chunk.IDAT do
  defstruct ~w(data)a

  def binary(%__MODULE__{} = idat) do
    Exiffer.PNG.Chunk.binary("IDAT", idat.data)
  end

  def text(%__MODULE__{} = idat) do
    """
    IDAT
    ----
    Data: #{byte_size(idat.data)} bytes
    """
  end

  def write(item, io_device) do
    binary = binary(item)
    :ok = IO.binwrite(io_device, binary)
  end

  defimpl Exiffer.Serialize do
    alias Exiffer.PNG.Chunk.IDAT

    def binary(idat) do
      IDAT.binary(idat)
    end

    def text(idat) do
      IDAT.text(idat)
    end

    def write(idat, io_device) do
      IDAT.write(idat, io_device)
    end
  end
end
