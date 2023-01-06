defmodule Exiffer.CLI.ReadTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  alias Exiffer.CLI.Read

  test "it reads JPEG files" do
    assert capture_io(fn ->
      Read.run("test/support/fixtures/exiffer_code.jpg")
    end) =~ "JPEG File Interchange Format\n"
  end

  test "it prints the JPEG version" do
    assert capture_io(fn ->
      Read.run("test/support/fixtures/exiffer_code.jpg")
    end) =~ "Version: 1.1\n"
  end

  test "it prints the JPEG X resolution" do
    assert capture_io(fn ->
      Read.run("test/support/fixtures/exiffer_code.jpg")
    end) =~ "X Resolution: 300\n"
  end

  test "it prints the JPEG Y resolution" do
    assert capture_io(fn ->
      Read.run("test/support/fixtures/exiffer_code.jpg")
    end) =~ "Y Resolution: 300\n"
  end

  test "it prints the JPEG comment" do
    assert capture_io(fn ->
      Read.run("test/support/fixtures/exiffer_code.jpg")
    end) =~ "Comment: Created with GIMP\n"
  end
end
