defmodule Exiffer.Chunk.IHDR do
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
end
