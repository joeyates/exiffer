defmodule Exiffer.Binary.RewriteTest do
  use ExUnit.Case, async: false

  alias Exiffer.Binary.Rewrite

  describe ".set_gps" do
    setup(context) do
      {:ok, binary} = File.read("test/support/fixtures/exiffer_code.jpg")
      gps_text = "1,2,3"

      [binary: binary, gps_text: gps_text]
    end

    test "it returns a binary", %{binary: binary, gps_text: gps_text} do
      result = Rewrite.set_gps(binary, gps_text)

      assert is_binary(result)
    end
  end
end
