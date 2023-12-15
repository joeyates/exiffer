defmodule Exiffer do
  @moduledoc """
  Documentation for `Exiffer`.
  """

  alias Exiffer.IO.Buffer
  alias Exiffer.{JPEG, PNG}

  @jpeg_magic <<0xff, 0xd8>>
  @png_magic <<0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a>>

  def parse(filename) when is_binary(filename) do
    buffer = Buffer.new(filename)
    {metadata, buffer} = parse(buffer)
    :ok = Buffer.close(buffer)

    metadata
  end

  def parse(%Buffer{data: <<@jpeg_magic, _rest::binary>>} = buffer) do
    {%JPEG{}, _buffer} = JPEG.new(buffer)
  end

  def parse(%Buffer{data: <<@png_magic, _rest::binary>>} = buffer) do
    {%PNG{}, _buffer} = PNG.new(buffer)
  end

  def parse(%{}) do
    raise "Unrecognized file format"
  end
end
