defmodule Exiffer.CLI.SetDateTimeTest do
  use ExUnit.Case
  require Logger
  import MixHelper
  import ExUnit.CaptureIO

  doctest Exiffer.CLI.SetDateTime

  @moduletag :tmp_dir

  @tag :tmp_dir
  test "it set date and time", config do
    source = Path.join(File.cwd!, "test/support/fixtures/with_exif.jpg")

    in_tmp_dir(config, fn ->
      opts = %{
        source: source,
        destination: "result.jpg",
        year: 2023,
        month: 12,
        day: 20,
        hour: 20,
        minute: 3,
        second: 8
      }

      Exiffer.CLI.SetDateTime.run(opts)

      assert_file("result.jpg")

      entries =
        capture_io(fn -> Exiffer.CLI.Read.run(%{filename: "result.jpg", format: "json"}) end)
        |> Jason.decode!()
        |> get_in(["headers", Access.at(0), "ifd_block", "ifds", Access.at(0), "entries"])
      entry = Enum.find(entries, fn e -> e["type"] == "modification_date" end)
      date = entry["value"]["Modification Date"]

      assert date == "2023-12-20 20:03:08"
    end)
  end
end
