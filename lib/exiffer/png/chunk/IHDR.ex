defmodule Exiffer.PNG.Chunk.IHDR do
  defstruct ~w(
    width
    height
    bits_per_sample
    color_type
    compression_method
    filter_method
    interlace_method
  )a

  require Logger

  alias Exiffer.Binary

  def new(data) do
    Logger.debug("Parsing IHDR")
    <<width::binary-size(4), height::binary-size(4), bits_per_sample, color_type, compression_method, filter_method, interlace_method>> = data
    %__MODULE__{
      width: Binary.to_integer(width),
      height: Binary.to_integer(height),
      bits_per_sample: bits_per_sample,
      color_type: color_type,
      compression_method: compression_method,
      filter_method: filter_method,
      interlace_method: interlace_method
    }
  end

  def binary(%__MODULE__{} = ihdr) do
    import Exiffer.Binary, only: [int32u_to_big_endian: 1]

    value = <<
      int32u_to_big_endian(ihdr.width),
      int32u_to_big_endian(ihdr.height),
      ihdr.bits_per_sample,
      ihdr.color_type,
      ihdr.compression_method,
      ihdr.filter_method,
      ihdr.interlace_method
    >>
    Exiffer.PNG.Chunk.binary("IHDR", value)
  end

  def text(%__MODULE__{} = ihdr) do
    """
    IHDR
    ----
    width: #{ihdr.width}
    height: #{ihdr.height}
    bits_per_sample: #{ihdr.bits_per_sample}
    color_type: #{ihdr.color_type}
    compression_method: #{ihdr.compression_method}
    filter_method: #{ihdr.filter_method}
    interlace_method: #{ihdr.interlace_method}
    """
  end

  def write(%__MODULE__{} = ihdr, io_device) do
    Logger.debug "Writing IHDR header"
    binary = binary(ihdr)
    :ok = IO.binwrite(io_device, binary)
  end

  defimpl Exiffer.Serialize do
    alias Exiffer.PNG.Chunk.IHDR

    def binary(data) do
      IHDR.binary(data)
    end

    def text(data) do
      IHDR.text(data)
    end

    def write(data, io_device) do
      IHDR.write(data, io_device)
    end
  end
end
