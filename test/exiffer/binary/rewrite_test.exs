defmodule Exiffer.Binary.RewriteTest do
  use ExUnit.Case, async: false

  alias Exiffer.Binary.{Buffer, Rewrite}

  def extract(binary, type) do
    buffer = Buffer.new(binary)
    {metadata, _buffer} = Exiffer.parse(buffer)
    metadata
    |> gps_info()
    |> entry_by_type(type)
  end

  def gps_info(metadata) do
    exif = Enum.find(metadata.headers, fn h -> h.__struct__ == Exiffer.Header.APP1.EXIF end)
    ifds = exif.ifd_block.ifds
    Enum.find_value(ifds, fn ifd ->
      Enum.find(ifd.entries, fn e -> e.type == :gps_info end)
    end)
  end

  def entry_by_type(%Exiffer.Entry{type: :gps_info} = gps_info, type) do
    Enum.find(gps_info.value.entries, fn e -> e.type == type end)
  end

  describe ".set_gps" do
    setup do
      {:ok, binary} = File.read("test/support/fixtures/exiffer_code.jpg")
      gps_text = "1,2,3"

      [binary: binary, gps_text: gps_text]
    end

    test "it returns a binary", %{binary: binary, gps_text: gps_text} do
      result = Rewrite.set_gps(binary, gps_text)

      assert is_binary(result)
    end

    test "it sets the latitude", %{binary: binary, gps_text: gps_text} do
      result = Rewrite.set_gps(binary, gps_text)

      latitude = extract(result, :gps_latitude)
      assert latitude.value == [{1, 1}, {0, 1}, {0, 1000000}]
    end

    test "it sets the longitude", %{binary: binary, gps_text: gps_text} do
      result = Rewrite.set_gps(binary, gps_text)

      longitude = extract(result, :gps_longitude)
      assert longitude.value == [{2, 1}, {0, 1}, {0, 1000000}]
    end

    test "it sets the altitude", %{binary: binary, gps_text: gps_text} do
      result = Rewrite.set_gps(binary, gps_text)

      longitude = extract(result, :gps_altitude)
      assert longitude.value == {3, 1}
    end
  end
end
