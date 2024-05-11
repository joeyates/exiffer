defmodule Exiffer.Binary.RewriteTest do
  use ExUnit.Case, async: false

  require Logger
  alias Exiffer.Binary.Rewrite

  setup do
    Logger.configure(level: :none)
    {:ok, binary} = File.read("test/support/fixtures/exiffer_code.jpg")

    [binary: binary]
  end

  test ".set_make_and_model", %{binary: binary} do
    result = Rewrite.set_make_and_model(binary, "Canon", "Canon EOS 90D")
    assert is_binary(result)
    headers = result|> Exiffer.parse_binary()|> Map.get(:headers)
    exif_index = find_exif_index(headers)
    ifd_entries = ifd_entries(headers,exif_index)

    make_entry = Enum.find(ifd_entries, &(&1.type == :make))
    assert make_entry.value == "Canon"

    model_entry = Enum.find(ifd_entries, &(&1.type == :model))
    assert model_entry.value == "Canon EOS 90D"
  end

  describe ".set_date_time" do
    @describetag date_time: NaiveDateTime.new!(1954, 4, 17, 8, 22, 51)

    test "it returns a binary", %{binary: binary, date_time: date_time} do
      result = Rewrite.set_date_time(binary, date_time)

      assert is_binary(result)
    end

    test "it adds a top-level modification time", %{binary: binary, date_time: date_time} do
      result = Rewrite.set_date_time(binary, date_time)
      entry = find_ifd_entry(result, :modification_date)
      assert entry.type == :modification_date
    end

    test "it formats the date", %{binary: binary, date_time: date_time} do
      result = Rewrite.set_date_time(binary, date_time)
      entry = find_ifd_entry(result, :modification_date)
      assert entry.value == "1954-04-17 08:22:51"
    end
  end

  describe ".set_gps" do
    @describetag gps: %{longitude: 2, latitude: 1, altitude: 3}

    def extract(binary, type) do
      binary
      |> Exiffer.parse_binary()
      |> gps_info()
      |> entry_by_type(type)
    end

    def gps_info(metadata) do
      exif = Enum.find(metadata.headers, &is_struct(&1, Exiffer.JPEG.Header.APP1.EXIF))

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
      assert latitude.value == [{1, 1}, {0, 1}, {0, 1_000_000}]
    end

    test "it sets the longitude", %{binary: binary, gps: gps} do
      result = Rewrite.set_gps(binary, gps)

      longitude = extract(result, :gps_longitude)
      assert longitude.value == [{2, 1}, {0, 1}, {0, 1_000_000}]
    end

    test "it sets the altitude", %{binary: binary, gps: gps} do
      result = Rewrite.set_gps(binary, gps)

      longitude = extract(result, :gps_altitude)
      assert longitude.value == {3, 1}
    end
  end

  ## helper functions
  defp find_ifd_entry(binary, entry_type) do
    headers =
      binary
      |> Exiffer.parse_binary()
      |> Map.get(:headers)

    exif_index = find_exif_index(headers)

    headers
    |> ifd_entries(exif_index)
    |> Enum.find(&(&1.type == entry_type))
  end

  defp find_exif_index(headers) do
    Enum.find_index(headers, &is_struct(&1, Exiffer.JPEG.Header.APP1.EXIF))
  end

  defp ifd_entries(headers, exif_index) do
    get_in(headers, ifd_entries_path(exif_index))
  end

  # We assume there is only one IFD in the EXIF block
  defp ifd_entries_path(exif_index) do
    [
      Access.at(exif_index),
      Access.key(:ifd_block),
      Access.key(:ifds),
      Access.at(0),
      Access.key(:entries)
    ]
  end
end
