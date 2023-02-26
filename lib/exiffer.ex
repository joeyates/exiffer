defmodule Exiffer do
  @moduledoc """
  Documentation for `Exiffer`.
  """

  alias Exiffer.JPEG

  @jpeg_magic <<0xff, 0xd8>>

  def parse(filename) when is_binary(filename) do
    buffer = Exiffer.IO.Buffer.new(filename)
    {metadata, buffer} = parse(buffer)
    :ok = Exiffer.IO.Buffer.close(buffer)

    metadata
  end

  def parse(%{data: <<@jpeg_magic, _rest::binary>>} = buffer) do
    {%JPEG{}, _buffer} = JPEG.new(buffer)
  end

  def parse(%{}) do
    raise "Unrecognized file format"
  end
end
