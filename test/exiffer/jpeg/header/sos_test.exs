defmodule Exiffer.JPEG.Header.SOSTest do
  use ExUnit.Case, async: false

  alias Exiffer.JPEG.Header.SOS

  def prepare_buffer(tail) do
    alias Exiffer.IO.Buffer

    image = <<0::size(10_000), 0xff, 0x00, 0::size(10_000)>>
    binary = <<0, 0, 0, 0, 0xff, 0xda, image::binary, tail::binary>>
    buffer =
      Buffer.new_from_binary(binary)
      |> Buffer.seek(4)
    {buffer, image}
  end

  setup do
    Logger.configure(level: :none)
  end

  test "it reads until the EOI header" do
    {buffer, image} = prepare_buffer(<<0xff, 0xd9>>)

    {:ok, sos, _buffer} = SOS.new(buffer)

    assert sos.data == image
  end

  test "it reads until the end of the file if not EIO is found" do
    {buffer, image} = prepare_buffer(<<>>)

    {:ok, sos, _buffer} = SOS.new(buffer)

    assert sos.data == image
  end
end
