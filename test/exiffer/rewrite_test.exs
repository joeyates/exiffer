defmodule Exiffer.RewriteTest do
  use ExUnit.Case, async: true

  alias Exiffer.Rewrite

  def get_modification_date_entry(headers) do
    get_in(headers, [
      Access.at(1),
      Access.key(:ifd_block),
      Access.key(:ifds),
      Access.at(0),
      Access.key(:entries),
      Access.at(1)
    ])
  end

  describe "JPEG" do
    test "it adds a top-level modification time" do
      filename = "test/support/fixtures/exiffer_code.jpg"
      date_time = NaiveDateTime.new!(1954, 4, 17, 8, 22, 51)
      input = Exiffer.IO.Buffer.new(filename)
      {:ok, headers, _remainder} = Rewrite.set_date_time(input, date_time)

      entry = get_modification_date_entry(headers)

      assert entry.type == :modification_date
    end

    test "it formats the date" do
      filename = "test/support/fixtures/exiffer_code.jpg"
      date_time = NaiveDateTime.new!(1954, 4, 17, 8, 22, 51)
      input = Exiffer.IO.Buffer.new(filename)
      {:ok, headers, _remainder} = Rewrite.set_date_time(input, date_time)

      entry = get_modification_date_entry(headers)

      assert entry.value == "1954-04-17 08:22:51"
    end
  end
end
