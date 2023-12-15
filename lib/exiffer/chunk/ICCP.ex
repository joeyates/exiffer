# http://www.libpng.org/pub/png/spec/1.2/PNG-Chunks.html#C.iCCP

defmodule Exiffer.Chunk.ICCP do
  defstruct ~w(name compression_method compressed_profile)a

  def new(data) do
    [name, rest] = String.split(data, <<0>>, parts: 2)
    <<compression_method, compressed_profile::binary>> = rest
    %__MODULE__{name: name, compression_method: compression_method, compressed_profile: compressed_profile}
  end
end
