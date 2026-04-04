defmodule Exiffer.RewriteTest do
  use ExUnit.Case, async: true

  import MixHelper

  alias Exiffer.Rewrite

  describe ".set_date_time/3" do
    @describetag :tmp_dir

    setup config do
      {:ok, source} = copy_tmp(config, "test/support/fixtures/code_with_samsung_trailer.jpg")
      destination = Path.join(config.tmp_dir, "result.jpeg")
      %{source: source, destination: destination}
    end

    test "sets modification_date", config do
      dt = ~N[2024-06-15 12:30:00]
      :ok = Rewrite.set_date_time(config.source, config.destination, dt)
      jpeg = Exiffer.parse(config.destination)
      assert {:ok, ~N[2024-06-15 12:30:00]} = Exiffer.JPEG.get_modification_date(jpeg)
    end

    test "sets date_time_original", config do
      dt = ~N[2024-06-15 12:30:00]
      :ok = Rewrite.set_date_time(config.source, config.destination, dt)
      jpeg = Exiffer.parse(config.destination)
      assert {:ok, ~N[2024-06-15 12:30:00]} = Exiffer.JPEG.get_date_time_original(jpeg)
    end

    test "sets create_date", config do
      dt = ~N[2024-06-15 12:30:00]
      :ok = Rewrite.set_date_time(config.source, config.destination, dt)
      jpeg = Exiffer.parse(config.destination)
      assert {:ok, ~N[2024-06-15 12:30:00]} = Exiffer.JPEG.get_create_date(jpeg)
    end

    test "accepts a DateTime", config do
      dt = DateTime.new!(~D[2024-06-15], ~T[12:30:00], "Etc/UTC")
      :ok = Rewrite.set_date_time(config.source, config.destination, dt)
      jpeg = Exiffer.parse(config.destination)
      assert {:ok, ~N[2024-06-15 12:30:00]} = Exiffer.JPEG.get_modification_date(jpeg)
    end
  end

  describe ".rewrite/3" do
    @describetag :tmp_dir

    setup config do
      {:ok, source} = copy_tmp(config, "test/support/fixtures/code_with_samsung_trailer.jpg")
      destination = Path.join(config.tmp_dir, "result.jpeg")
      %{source: source, destination: destination}
    end

    test "passes a %JPEG structure to the callback", config do
      Rewrite.rewrite(config.source, config.destination, fn jpeg ->
        send(self(), {:parameter, jpeg})
        jpeg
      end)

      assert_received {:parameter, %Exiffer.JPEG{}}
    end

    test "with noop, creates an identical file", config do
      source_stat = File.stat!(config.source)
      Rewrite.rewrite(config.source, config.destination, fn jpeg -> jpeg end)
      destination_stat = File.stat!(config.destination)

      assert destination_stat.mtime == source_stat.mtime
      assert destination_stat.size == source_stat.size
      assert destination_stat.mode == source_stat.mode
    end
  end

  describe ".set_make_and_model/4" do
    @describetag :tmp_dir

    setup config do
      {:ok, source} = copy_tmp(config, "test/support/fixtures/code_with_samsung_trailer.jpg")
      destination = Path.join(config.tmp_dir, "result.jpeg")
      %{source: source, destination: destination}
    end

    test "sets make", config do
      :ok = Rewrite.set_make_and_model(config.source, config.destination, "Acme", "Cam 1")
      jpeg = Exiffer.parse(config.destination)
      assert {:ok, "Acme"} = Exiffer.JPEG.get_exif_field(jpeg, :make)
    end

    test "sets model", config do
      :ok = Rewrite.set_make_and_model(config.source, config.destination, "Acme", "Cam 1")
      jpeg = Exiffer.parse(config.destination)
      assert {:ok, "Cam 1"} = Exiffer.JPEG.get_exif_field(jpeg, :model)
    end
  end

  describe ".set_gps/3" do
    @describetag :tmp_dir

    setup config do
      {:ok, source} = copy_tmp(config, "test/support/fixtures/code_with_samsung_trailer.jpg")
      destination = Path.join(config.tmp_dir, "result.jpeg")
      gps = %Exiffer.GPS{latitude: 51.5, longitude: -0.1, altitude: 10.0}
      %{source: source, destination: destination, gps: gps}
    end

    test "sets the GPS data", config do
      :ok = Rewrite.set_gps(config.source, config.destination, config.gps)
      jpeg = Exiffer.parse(config.destination)
      assert {:ok, %Exiffer.GPS{} = result} = Exiffer.JPEG.get_gps(jpeg)
      assert_in_delta result.latitude, 51.5, 0.01
      assert_in_delta result.longitude, -0.1, 0.01
      assert_in_delta result.altitude, 10.0, 0.01
    end

    test "overwrites existing GPS data", config do
      :ok = Rewrite.set_gps(config.source, config.destination, config.gps)
      gps2 = %Exiffer.GPS{latitude: 48.85, longitude: 2.35, altitude: 35.0}
      :ok = Rewrite.set_gps(config.destination, config.destination, gps2)
      jpeg = Exiffer.parse(config.destination)
      assert {:ok, %Exiffer.GPS{} = result} = Exiffer.JPEG.get_gps(jpeg)
      assert_in_delta result.latitude, 48.85, 0.02
      assert_in_delta result.longitude, 2.35, 0.02
    end
  end
end
