defmodule Exiffer.JPEGTest do
  use ExUnit.Case, async: true

  import Exiffer.Fixtures.JPEG

  alias Exiffer.JPEG
  alias Exiffer.GPS
  alias Exiffer.JPEG.Header.Junk

  describe "magic/0" do
    test "returns the JPEG magic bytes" do
      assert JPEG.magic() == <<0xFF, 0xD8>>
    end
  end

  describe "dimensions/1" do
    test "returns dimensions from SOF0 when present" do
      assert JPEG.dimensions(with_sof0()) == %{width: 640, height: 480}
    end

    test "returns dimensions from EXIF when no SOF0" do
      assert JPEG.dimensions(with_exif_dimensions()) == %{width: 1920, height: 1080}
    end

    test "returns nil when no SOF0 and no EXIF" do
      assert JPEG.dimensions(no_exif()) == nil
    end

    test "prefers SOF0 over EXIF dimensions" do
      jpeg = %JPEG{headers: with_sof0().headers ++ with_exif_dimensions().headers}
      assert JPEG.dimensions(jpeg) == %{width: 640, height: 480}
    end
  end

  describe "remove_non_standard_headers/1" do
    test "removes Junk headers" do
      jpeg = %JPEG{headers: [%Junk{data: "garbage"}, hd(minimal_exif().headers)]}
      result = JPEG.remove_non_standard_headers(jpeg)
      refute Enum.any?(result.headers, &is_struct(&1, Junk))
    end

    test "keeps non-Junk headers" do
      jpeg = %JPEG{headers: [%Junk{data: "garbage"}] ++ minimal_exif().headers}
      result = JPEG.remove_non_standard_headers(jpeg)
      assert length(result.headers) == length(minimal_exif().headers)
    end

    test "returns unchanged JPEG when there are no Junk headers" do
      result = JPEG.remove_non_standard_headers(minimal_exif())
      assert result == minimal_exif()
    end
  end

  describe "get_exif_field/2" do
    test "returns the value for the given type" do
      assert {:ok, 3286} = JPEG.get_exif_field(minimal_exif(), :image_width)
    end

    test "returns an error tuple if there is no EXIF header" do
      assert {:error, _message} = JPEG.get_exif_field(no_exif(), :image_width)
    end

    test "returns an error tuple if there is no entry of the given type" do
      assert {:error, _message} = JPEG.get_exif_field(minimal_exif(), :make)
    end
  end

  describe "set_exif_field/3" do
    test "updates an existing entry and returns the updated JPEG" do
      result = JPEG.set_exif_field(minimal_exif(), :image_width, 1920)

      entry =
        get_in(result.headers, [
          Access.at(1),
          Access.key(:ifd_block),
          Access.key(:ifds),
          Access.at(0),
          Access.key(:entries),
          Access.at(0)
        ])

      assert entry.value == 1920
    end

    test "adds a new entry when the field does not exist" do
      result = JPEG.set_exif_field(minimal_exif(), :make, "Canon")

      entry =
        get_in(result.headers, [
          Access.at(1),
          Access.key(:ifd_block),
          Access.key(:ifds),
          Access.at(0),
          Access.key(:entries),
          Access.at(0)
        ])

      assert entry.value == "Canon"
    end

    test "preserves other existing entries" do
      result = JPEG.set_exif_field(minimal_exif(), :make, "Canon")

      entry =
        get_in(
          result.headers,
          [
            Access.at(1),
            Access.key(:ifd_block),
            Access.key(:ifds),
            Access.at(0),
            Access.key(:entries),
            Access.at(1)
          ]
        )

      assert entry.value == 3286
    end
  end

  describe "exif_index/1" do
    test "returns the index of the EXIF header, when passed a JPEG" do
      assert JPEG.exif_index(minimal_exif()) == 1
    end

    test "returns the index of the EXIF header, when passed headers" do
      assert JPEG.exif_index(minimal_exif().headers) == 1
    end

    test "returns nil if there is no EXIF header" do
      assert JPEG.exif_index(no_exif().headers) == nil
    end
  end

  describe "exif_entry/2" do
    test "returns the entry for the given type, when passed a JPEG" do
      {:ok, result} = JPEG.exif_entry(minimal_exif(), :image_width)

      assert result == %Exiffer.JPEG.Entry{
               type: :image_width,
               format: :int16u,
               label: "Image Width",
               magic: <<1, 0>>,
               value: 3286
             }
    end

    test "returns an error tuple if there is no EXIF header" do
      assert {:error, _message} = JPEG.exif_entry(no_exif(), :image_width)
    end

    test "returns an error tuple if there is no entry of the given type" do
      assert {:error, _message} = JPEG.exif_entry(minimal_exif(), :make)
    end
  end

  describe "has_exif_entry?/2" do
    test "returns true when the entry exists" do
      assert JPEG.has_exif_entry?(minimal_exif(), :image_width)
    end

    test "returns false when there is no EXIF header" do
      refute JPEG.has_exif_entry?(no_exif(), :image_width)
    end

    test "returns false when there is no entry of the given type" do
      refute JPEG.has_exif_entry?(minimal_exif(), :make)
    end
  end

  describe "get_sub_ifd_field/3" do
    test "returns the value for the given sub-IFD block and type" do
      assert {:ok, {99998, 1_000_000}} =
               JPEG.get_sub_ifd_field(with_exif_sub_ifd(), :exif_offset, :exposure_time)
    end

    test "returns an error tuple when there is no EXIF header" do
      assert {:error, _message} = JPEG.get_sub_ifd_field(no_exif(), :exif_offset, :exposure_time)
    end

    test "returns an error tuple when the sub-IFD block does not exist" do
      assert {:error, _message} =
               JPEG.get_sub_ifd_field(minimal_exif(), :exif_offset, :exposure_time)
    end

    test "returns an error tuple when the entry type does not exist in the sub-IFD" do
      assert {:error, _message} =
               JPEG.get_sub_ifd_field(with_exif_sub_ifd(), :exif_offset, :make)
    end
  end

  describe "set_sub_ifd_field/4" do
    test "updates an existing entry" do
      result = JPEG.set_sub_ifd_field(with_exif_sub_ifd(), :exif_offset, :exposure_time, {1, 100})

      entry =
        get_in(result.headers, [
          Access.at(1),
          Access.key(:ifd_block),
          Access.key(:ifds),
          Access.at(0),
          Access.key(:entries),
          Access.at(2),
          Access.key(:value),
          Access.key(:entries),
          Access.at(0)
        ])

      assert entry.value == {1, 100}
    end

    test "adds a new entry to an existing sub-IFD block" do
      result = JPEG.set_sub_ifd_field(with_exif_sub_ifd(), :exif_offset, :iso, 400)

      entry =
        get_in(result.headers, [
          Access.at(1),
          Access.key(:ifd_block),
          Access.key(:ifds),
          Access.at(0),
          Access.key(:entries),
          Access.at(2),
          Access.key(:value),
          Access.key(:entries),
          Access.at(0)
        ])

      assert entry.value == 400
    end

    test "creates the sub-IFD block when it does not exist" do
      result = JPEG.set_sub_ifd_field(minimal_exif(), :exif_offset, :exposure_time, {1, 200})

      entry =
        get_in(result.headers, [
          Access.at(1),
          Access.key(:ifd_block),
          Access.key(:ifds),
          Access.at(0),
          Access.key(:entries),
          Access.at(0),
          Access.key(:value),
          Access.key(:entries),
          Access.at(0)
        ])

      assert entry.value == {1, 200}
    end

    test "preserves other entries in the sub-IFD block" do
      result = JPEG.set_sub_ifd_field(with_exif_sub_ifd(), :exif_offset, :iso, 400)

      entry =
        get_in(result.headers, [
          Access.at(1),
          Access.key(:ifd_block),
          Access.key(:ifds),
          Access.at(0),
          Access.key(:entries),
          Access.at(2),
          Access.key(:value),
          Access.key(:entries),
          Access.at(1)
        ])

      assert entry.value == {99998, 1_000_000}
    end
  end

  describe "sub_ifd_field/3" do
    test "returns the value for the given sub-IFD block and type" do
      assert {:ok, {99998, 1_000_000}} =
               JPEG.sub_ifd_field(with_exif_sub_ifd(), :exif_offset, :exposure_time)
    end

    test "returns an error tuple when there is no EXIF header" do
      assert {:error, _message} = JPEG.sub_ifd_field(no_exif(), :exif_offset, :exposure_time)
    end

    test "returns an error tuple when the sub-IFD block does not exist" do
      assert {:error, _message} = JPEG.sub_ifd_field(minimal_exif(), :exif_offset, :exposure_time)
    end

    test "returns an error tuple when the entry type does not exist in the sub-IFD" do
      assert {:error, _message} = JPEG.sub_ifd_field(with_exif_sub_ifd(), :exif_offset, :make)
    end
  end

  describe "sub_ifd_entry/3" do
    test "returns the entry for the given sub-IFD block and type" do
      {:ok, result} = JPEG.sub_ifd_entry(with_exif_sub_ifd(), :exif_offset, :exposure_time)

      assert result == %Exiffer.JPEG.Entry{
               type: :exposure_time,
               format: :rational_64u,
               label: "Exposure Time",
               magic: <<130, 154>>,
               value: {99998, 1_000_000}
             }
    end

    test "returns an error tuple when there is no EXIF header" do
      assert {:error, _message} = JPEG.sub_ifd_entry(no_exif(), :exif_offset, :exposure_time)
    end

    test "returns an error tuple when the sub-IFD block does not exist" do
      assert {:error, _message} = JPEG.sub_ifd_entry(minimal_exif(), :exif_offset, :exposure_time)
    end

    test "returns an error tuple when the entry type does not exist in the sub-IFD" do
      assert {:error, _message} = JPEG.sub_ifd_entry(with_exif_sub_ifd(), :exif_offset, :make)
    end
  end

  describe "gps_entry/1" do
    test "returns the gps_info entry" do
      {:ok, result} = JPEG.gps_entry(with_gps())
      assert result.type == :gps_info
    end

    test "returns an error tuple when there is no EXIF header" do
      assert {:error, _message} = JPEG.gps_entry(no_exif())
    end

    test "returns an error tuple when there is no gps_info entry" do
      assert {:error, _message} = JPEG.gps_entry(minimal_exif())
    end
  end

  describe "has_gps_entry?/1" do
    test "returns true when the gps_info entry exists" do
      assert JPEG.has_gps_entry?(with_gps())
    end

    test "returns false when there is no EXIF header" do
      refute JPEG.has_gps_entry?(no_exif())
    end

    test "returns false when there is no gps_info entry" do
      refute JPEG.has_gps_entry?(minimal_exif())
    end
  end

  describe "get_gps/1" do
    test "returns a GPS struct for a JPEG with valid GPS data" do
      gps = %GPS{latitude: 51.5, longitude: -0.1, altitude: 10.0}
      jpeg = JPEG.set_gps(minimal_exif(), gps)

      assert {:ok, %GPS{latitude: latitude, longitude: longitude, altitude: altitude}} =
               JPEG.get_gps(jpeg)

      assert_in_delta latitude, 51.5, 0.01
      assert_in_delta longitude, -0.1, 0.01
      assert_in_delta altitude, 10.0, 0.01
    end

    test "returns an error tuple when there is no EXIF header" do
      assert {:error, _message} = JPEG.get_gps(no_exif())
    end

    test "returns an error tuple when there is no gps_info entry" do
      assert {:error, _message} = JPEG.get_gps(minimal_exif())
    end
  end

  describe "set_gps/2" do
    test "sets the gps_info entry on a JPEG with no existing GPS data" do
      gps = %GPS{latitude: 51.5, longitude: -0.1, altitude: 10.0}
      result = JPEG.set_gps(minimal_exif(), gps)

      entry =
        get_in(result.headers, [
          Access.at(1),
          Access.key(:ifd_block),
          Access.key(:ifds),
          Access.at(0),
          Access.key(:entries),
          Access.at(0)
        ])

      assert entry.type == :gps_info

      assert entry.value.entries |> Enum.find(&(&1.type == :gps_latitude_ref)) |> Map.get(:value) ==
               "N"
    end

    test "updates an existing gps_info entry" do
      gps = %GPS{latitude: 48.85, longitude: 2.35, altitude: 35.0}
      result = JPEG.set_gps(with_gps(), gps)

      entry =
        get_in(result.headers, [
          Access.at(1),
          Access.key(:ifd_block),
          Access.key(:ifds),
          Access.at(0),
          Access.key(:entries),
          Access.at(0)
        ])

      assert entry.type == :gps_info

      assert entry.value.entries |> Enum.find(&(&1.type == :gps_longitude_ref)) |> Map.get(:value) ==
               "E"
    end

    test "sets southern/western hemisphere refs correctly" do
      gps = %GPS{latitude: -33.87, longitude: -70.65, altitude: 520.0}
      result = JPEG.set_gps(minimal_exif(), gps)

      entry =
        get_in(result.headers, [
          Access.at(1),
          Access.key(:ifd_block),
          Access.key(:ifds),
          Access.at(0),
          Access.key(:entries),
          Access.at(0)
        ])

      assert entry.value.entries |> Enum.find(&(&1.type == :gps_latitude_ref)) |> Map.get(:value) ==
               "S"

      assert entry.value.entries |> Enum.find(&(&1.type == :gps_longitude_ref)) |> Map.get(:value) ==
               "W"
    end
  end

  describe "get_modification_date/1" do
    test "returns the modification_date value" do
      dt = ~N[2024-06-15 12:30:00]
      jpeg = JPEG.set_modification_date(minimal_exif(), dt)
      assert {:ok, ~N[2024-06-15 12:30:00]} = JPEG.get_modification_date(jpeg)
    end

    test "returns an error tuple when there is no EXIF header" do
      assert {:error, _message} = JPEG.get_modification_date(no_exif())
    end

    test "returns an error tuple when the field is not set" do
      assert {:error, _message} = JPEG.get_modification_date(minimal_exif())
    end
  end

  describe "set_modification_date/2" do
    test "sets the modification_date field" do
      dt = ~N[2024-06-15 12:30:00]
      result = JPEG.set_modification_date(minimal_exif(), dt)
      assert {:ok, ~N[2024-06-15 12:30:00]} = JPEG.get_modification_date(result)
    end

    test "updates an existing modification_date field" do
      dt1 = ~N[2020-01-01 00:00:00]
      dt2 = ~N[2024-06-15 12:30:00]

      result =
        minimal_exif() |> JPEG.set_modification_date(dt1) |> JPEG.set_modification_date(dt2)

      assert {:ok, ~N[2024-06-15 12:30:00]} = JPEG.get_modification_date(result)
    end
  end

  describe "get_date_time_original/1" do
    test "returns the date_time_original value" do
      dt = ~N[2024-06-15 12:30:00]
      jpeg = JPEG.set_date_time_original(minimal_exif(), dt)
      assert {:ok, ~N[2024-06-15 12:30:00]} = JPEG.get_date_time_original(jpeg)
    end

    test "returns an error tuple when there is no EXIF header" do
      assert {:error, _message} = JPEG.get_date_time_original(no_exif())
    end

    test "returns an error tuple when the field is not set" do
      assert {:error, _message} = JPEG.get_date_time_original(minimal_exif())
    end
  end

  describe "set_date_time_original/2" do
    test "sets the date_time_original field" do
      dt = ~N[2024-06-15 12:30:00]
      result = JPEG.set_date_time_original(minimal_exif(), dt)
      assert {:ok, ~N[2024-06-15 12:30:00]} = JPEG.get_date_time_original(result)
    end

    test "updates an existing date_time_original field" do
      dt1 = ~N[2020-01-01 00:00:00]
      dt2 = ~N[2024-06-15 12:30:00]

      result =
        minimal_exif() |> JPEG.set_date_time_original(dt1) |> JPEG.set_date_time_original(dt2)

      assert {:ok, ~N[2024-06-15 12:30:00]} = JPEG.get_date_time_original(result)
    end
  end

  describe "get_create_date/1" do
    test "returns the create_date value" do
      dt = ~N[2024-06-15 12:30:00]
      jpeg = JPEG.set_create_date(minimal_exif(), dt)
      assert {:ok, ~N[2024-06-15 12:30:00]} = JPEG.get_create_date(jpeg)
    end

    test "returns an error tuple when there is no EXIF header" do
      assert {:error, _message} = JPEG.get_create_date(no_exif())
    end

    test "returns an error tuple when the field is not set" do
      assert {:error, _message} = JPEG.get_create_date(minimal_exif())
    end
  end

  describe "set_create_date/2" do
    test "sets the create_date field" do
      dt = ~N[2024-06-15 12:30:00]
      result = JPEG.set_create_date(minimal_exif(), dt)
      assert {:ok, ~N[2024-06-15 12:30:00]} = JPEG.get_create_date(result)
    end

    test "updates an existing create_date field" do
      dt1 = ~N[2020-01-01 00:00:00]
      dt2 = ~N[2024-06-15 12:30:00]
      result = minimal_exif() |> JPEG.set_create_date(dt1) |> JPEG.set_create_date(dt2)
      assert {:ok, ~N[2024-06-15 12:30:00]} = JPEG.get_create_date(result)
    end
  end
end
