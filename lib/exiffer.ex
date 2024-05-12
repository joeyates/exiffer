defmodule Exiffer do
  @moduledoc """
  Documentation for `Exiffer`.
  """

  alias Exiffer.IO.Buffer
  alias Exiffer.{JPEG, PNG}

  @jpeg_magic <<0xFF, 0xD8>>
  @png_magic <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>

  def parse(filename) when is_binary(filename) do
    buffer = Buffer.new(filename)
    {metadata, buffer} = parse(buffer)
    :ok = Buffer.close(buffer)

    metadata
  end

  def parse(%{data: <<@jpeg_magic, _rest::binary>>} = buffer) do
    {%JPEG{}, _buffer} = JPEG.new(buffer)
  end

  def parse(%{data: <<@png_magic, _rest::binary>>} = buffer) do
    {%PNG{}, _buffer} = PNG.new(buffer)
  end

  def parse(%{}) do
    raise "Unrecognized file format"
  end

  def parse_binary(binary) when is_binary(binary) do
    buffer = Buffer.new_from_binary(binary)
    {metadata, buffer} = parse(buffer)
    :ok = Buffer.close(buffer)

    metadata
  end
end
