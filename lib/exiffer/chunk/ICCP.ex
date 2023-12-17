# http://www.libpng.org/pub/png/spec/1.2/PNG-Chunks.html#C.iCCP

defmodule Exiffer.Chunk.ICCP do
  @keys ~w(name compression_method compressed_profile)a
  @enforce_keys @keys
  defstruct @keys

  def new(data) do
    [name, rest] = String.split(data, <<0>>, parts: 2)
    <<compression_method, compressed_profile::binary>> = rest
    %__MODULE__{name: name, compression_method: compression_method, compressed_profile: compressed_profile}
  end

  @spec binary(%Exiffer.Chunk.ICCP{
          :compressed_profile => binary,
          :compression_method => integer,
          :name => integer()
        }) :: binary
  def binary(%__MODULE__{} = iccp) do
    value = <<
      iccp.name,
      0,
      iccp.compression_method,
      iccp.compressed_profile
    >>
    Exiffer.Chunk.binary("iCCP", value)
  end

  @spec puts(%Exiffer.Chunk.ICCP{
          :compressed_profile => binary,
          :compression_method => integer,
          :name => String.t()
        }) :: :ok
  def puts(%__MODULE__{} = iccp) do
    IO.puts """
    iCCP
    ----
    name: #{iccp.name}
    compression_method: #{iccp.compression_method}
    compressed_profile: #{byte_size(iccp.compressed_profile)} bytes
    """
  end

  def write(item, io_device) do
    binary = binary(item)
    :ok = IO.binwrite(io_device, binary)
  end

  defimpl Exiffer.Serialize do
    alias Exiffer.Chunk.ICCP

    require Logger

    @spec binary(%Exiffer.Chunk.ICCP{}) :: binary
    def binary(iccp) do
      ICCP.binary(iccp)
    end

    @spec puts(%Exiffer.Chunk.ICCP{}) :: nil
    def puts(iccp) do
      ICCP.puts(iccp)
    end

    @spec write(%Exiffer.Chunk.ICCP{}, any) :: nil
    def write(iccp, io_device) do
      Logger.debug "Writing iCCP header"
      ICCP.write(iccp, io_device)
    end
  end
end
