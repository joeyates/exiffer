defmodule Exiffer.OffsetBuffer do
  @moduledoc """
  Documentation for `Exiffer.OffsetBuffer`.

  Wraps Exiffer.Buffer with appending an offset amount to positions
  """

  alias Exiffer.Buffer
  require Logger

  @enforce_keys ~w(buffer offset)a
  defstruct ~w(buffer offset)a

  def new(%{} = buffer, offset \\ 0) do
    %__MODULE__{buffer: buffer, offset: offset}
  end

  def seek(%__MODULE__{buffer: buffer, offset: offset} = offset_buffer, position) do
    new_position = offset + position
    buffer = Buffer.seek(buffer, new_position)
    struct!(offset_buffer, buffer: buffer)
  end

  def consume(%__MODULE__{buffer: buffer} = offset_buffer, amount) do
    {result, buffer} = Buffer.consume(buffer, amount)
    {result, struct!(offset_buffer, buffer: buffer)}
  end

  def skip(%__MODULE__{buffer: buffer} = offset_buffer, amount) do
    buffer = Buffer.skip(buffer, amount)
    struct!(offset_buffer, buffer: buffer)
  end

  def random(%__MODULE__{buffer: buffer, offset: offset}, position, count) do
    Buffer.random(buffer, offset + position, count)
  end

  def tell(%__MODULE__{buffer: buffer, offset: offset}) do
    buffer.position - offset
  end

  defimpl Exiffer.Buffer do
    alias Exiffer.OffsetBuffer

    def offset_buffer(buffer, offset) do
      OffsetBuffer.new(buffer.buffer, offset)
    end

    def consume(buffer, count) do
      OffsetBuffer.consume(buffer, count)
    end

    def seek(buffer, position) do
      OffsetBuffer.seek(buffer, position)
    end

    def skip(buffer, count) do
      OffsetBuffer.skip(buffer, count)
    end

    def random(buffer, read_position, count) do
      OffsetBuffer.random(buffer, read_position, count)
    end

    def tell(buffer) do
      OffsetBuffer.tell(buffer)
    end
  end
end
