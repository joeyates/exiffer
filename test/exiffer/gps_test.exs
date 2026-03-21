defmodule Exiffer.GPSTest do
  use ExUnit.Case, async: true

  alias Exiffer.GPS

  describe ".parse/1" do
    @inputs %{longitude: "123.4", latitude: "99.0", altitude: "33"}

    test "parses numeric longitude" do
      {:ok, gps} = GPS.parse(@inputs)

      assert gps.longitude == 123.4
    end

    test "parses degrees, minutes and seconds longitude" do
      {:ok, gps} = GPS.parse(%{@inputs | longitude: "23°15′34″E"})

      assert_in_delta gps.longitude, 23.259444, 0.000001
    end

    test "interprets W as negative" do
      {:ok, gps} = GPS.parse(%{@inputs | longitude: "23°15′34″W"})

      assert_in_delta gps.longitude, -23.259444, 0.000001
    end

    test "returns error if longitude is unparseable" do
      {:error, reason} = GPS.parse(%{@inputs | longitude: "AAA"})

      assert reason =~ ~r/Failed to parse longitude/i
    end

    test "parses numeric latitude" do
      {:ok, gps} = GPS.parse(@inputs)

      assert gps.latitude == 99.0
    end

    test "parses degrees, minutes and seconds latitude" do
      {:ok, gps} = GPS.parse(%{@inputs | latitude: "23°15′34″N"})

      assert_in_delta gps.latitude, 23.259444, 0.000001
    end

    test "interprets S as negative" do
      {:ok, gps} = GPS.parse(%{@inputs | latitude: "23°15′34″S"})

      assert_in_delta gps.latitude, -23.259444, 0.000001
    end

    test "returns error if latitude is unparseable" do
      {:error, reason} = GPS.parse(%{@inputs | latitude: "AAA"})

      assert reason =~ ~r/Failed to parse latitude/i
    end

    test "parses numeric altitude" do
      {:ok, gps} = GPS.parse(@inputs)

      assert gps.altitude == 33.0
    end
  end
end
