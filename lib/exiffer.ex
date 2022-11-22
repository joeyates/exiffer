defmodule Exiffer do
  @moduledoc """
  Documentation for `Exiffer`.
  """

  alias Exiffer.Buffer
  alias Exiffer.JPEG

  @jpeg_magic <<0xff, 0xd8>>

  def parse(filename) when is_binary(filename) do
    buffer = Buffer.new(filename)
    {headers, _buffer} = parse(buffer)
    :ok = Buffer.close(buffer)

    headers
  end

  def parse(%Buffer{data: <<@jpeg_magic, _rest::binary>>} = buffer) do
    # TODO: Move this into JPEG.new
    buffer = Buffer.skip(buffer, 2)
    {buffer, headers} = JPEG.headers(buffer, [])
    headers = Enum.reverse(headers)
    {headers, buffer}
  end

  def parse(%Buffer{}) do
    raise "Unrecognized file format"
  end
end
