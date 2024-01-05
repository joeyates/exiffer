defmodule Exiffer.Binary.RewriteTest do
  use ExUnit.Case, async: false

  require Logger
  alias Exiffer.Binary.Rewrite
  alias Exiffer.IO.Buffer

  setup do
    Logger.configure(level: :none)
    {:ok, binary} = File.read("test/support/fixtures/exiffer_code.jpg")

    [binary: binary]
  end

  describe ".set_date_time" do
    @describetag date_time: NaiveDateTime.new!(1954, 4, 17, 8, 22, 51)

    def get_modification_date_entry(binary) do
      buffer = Buffer.new_from_binary(binary)
      {jpeg, buffer} = Exiffer.parse(buffer)
      Buffer.close(buffer)
      get_in(jpeg.headers, [
        Access.at(1),
        Access.key(:ifd_block),
        Access.key(:ifds),
        Access.at(0),
        Access.key(:entries),
      ])
      |> Enum.find(& &1.type == :modification_date)
    end

    test "it returns a binary", %{binary: binary, date_time: date_time} do
      result = Rewrite.set_date_time(binary, date_time)

      assert is_binary(result)
    end

    test "it adds a top-level modification time", %{binary: binary, date_time: date_time} do
      result = Rewrite.set_date_time(binary, date_time)

      entry = get_modification_date_entry(result)

      assert entry.type == :modification_date
    end

    test "it formats the date", %{binary: binary, date_time: date_time} do
      result = Rewrite.set_date_time(binary, date_time)

      entry = get_modification_date_entry(result)

      assert entry.value == "1954-04-17 08:22:51"
    end
  end

  describe ".set_gps" do
    @describetag gps: %{longitude: 2, latitude: 1, altitude: 3}

    def extract(binary, type) do
      buffer = Buffer.new_from_binary(binary)
      {metadata, buffer} = Exiffer.parse(buffer)
      Buffer.close(buffer)
      metadata
      |> gps_info()
      |> entry_by_type(type)
    end

    def gps_info(metadata) do
      exif = Enum.find(metadata.headers, fn h -> h.__struct__ == Exiffer.JPEG.Header.APP1.EXIF end)
      ifds = exif.ifd_block.ifds
      Enum.find_value(ifds, fn ifd ->
        Enum.find(ifd.entries, fn e -> e.type == :gps_info end)
      end)
    end

    def entry_by_type(%Exiffer.JPEG.Entry{type: :gps_info} = gps_info, type) do
      Enum.find(gps_info.value.entries, fn e -> e.type == type end)
    end

    test "it returns a binary", %{binary: binary, gps: gps} do
      result = Rewrite.set_gps(binary, gps)

      assert is_binary(result)
    end

    test "it sets the latitude", %{binary: binary, gps: gps} do
      result = Rewrite.set_gps(binary, gps)

      latitude = extract(result, :gps_latitude)
      assert latitude.value == [{1, 1}, {0, 1}, {0, 1000000}]
    end

    test "it sets the longitude", %{binary: binary, gps: gps} do
      result = Rewrite.set_gps(binary, gps)

      longitude = extract(result, :gps_longitude)
      assert longitude.value == [{2, 1}, {0, 1}, {0, 1000000}]
    end

    test "it sets the altitude", %{binary: binary, gps: gps} do
      result = Rewrite.set_gps(binary, gps)

      longitude = extract(result, :gps_altitude)
      assert longitude.value == {3, 1}
    end
  end
end
