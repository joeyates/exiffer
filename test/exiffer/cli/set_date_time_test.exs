defmodule Exiffer.CLI.SetDateTimeTest do
  use ExUnit.Case
  require Logger
  doctest Exiffer.CLI.SetDateTime

  test "roundtrip" do
    Logger.configure(level: :none)
    opts = %{
      source: "test/support/fixtures/with_exif.jpg",
      destination: "result.jpg",
      year: 2023,
      month: 12,
      day: 20,
      hour: 20,
      minute: 3,
      second: 8
    }

    Exiffer.CLI.SetDateTime.run(opts)
  end
end
