defmodule Exiffer.IO.BufferTest do
  use ExUnit.Case, async: true

  alias Exiffer.IO.Buffer

  describe "push/2" do
    setup do
      buffer = Buffer.new_from_binary(<<1, 2, 3, 4, 5>>)
      %{buffer: buffer}
    end

    test "prepends the chunk to the buffer data", %{buffer: buffer} do
      {_consumed, buffer} = Buffer.consume(buffer, 2)
      buffer = Buffer.push(buffer, <<1, 2>>)

      assert binary_part(buffer.data, 0, 2) == <<1, 2>>
    end

    test "increases remaining by the chunk size", %{buffer: buffer} do
      {_consumed, buffer} = Buffer.consume(buffer, 2)
      remaining_before = buffer.remaining
      buffer = Buffer.push(buffer, <<1, 2>>)

      assert buffer.remaining == remaining_before + 2
    end

    test "decrements position by the chunk size", %{buffer: buffer} do
      {_consumed, buffer} = Buffer.consume(buffer, 2)
      position_before = buffer.position
      buffer = Buffer.push(buffer, <<1, 2>>)

      assert buffer.position == position_before - 2
    end

    test "restores position to the original after pushing consumed bytes back", %{buffer: buffer} do
      original_position = buffer.position
      {consumed, buffer} = Buffer.consume(buffer, 2)
      buffer = Buffer.push(buffer, consumed)

      assert buffer.position == original_position
    end
  end
end
