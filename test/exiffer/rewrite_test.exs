defmodule Exiffer.RewriteTest do
  use ExUnit.Case, async: true

  import MixHelper

  alias Exiffer.Rewrite

  describe ".rewrite/3" do
    @describetag :tmp_dir

    setup config do
      {:ok, source} = copy_tmp(config, "test/support/fixtures/exiffer_code.jpg")
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
end
