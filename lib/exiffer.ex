defmodule Exiffer do
  @moduledoc """
  Documentation for `Exiffer`.
  """

  alias Exiffer.IO.Buffer
  alias Exiffer.JPEG

  @jpeg_magic <<0xff, 0xd8>>

  def parse(filename) when is_binary(filename) do
    buffer = Buffer.new(filename)
    {metadata, buffer} = parse(buffer)
    :ok = Buffer.close(buffer)

    metadata
  end

  def parse(%Buffer{data: <<@jpeg_magic, _rest::binary>>} = buffer) do
    {%JPEG{}, _buffer} = JPEG.new(buffer)
  end

  def parse(%{}) do
    raise "Unrecognized file format"
  end
end
