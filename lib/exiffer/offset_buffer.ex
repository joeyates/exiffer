defmodule Exiffer.OffsetBuffer do
  @moduledoc """
  Documentation for `Exiffer.OffsetBuffer`.

  Wraps Exiffer.Buffer with appending an offset amount to positions
  """

  alias Exiffer.Buffer

  defstruct [:buffer, :offset]

  def new(%Buffer{} = buffer, offset \\ 0) do
    %__MODULE__{buffer: buffer, offset: offset}
  end

  def seek(%__MODULE__{buffer: buffer, offset: offset} = offset_buffer, position) do
    buffer = Buffer.seek(buffer, offset + position)
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

  def random(%__MODULE__{buffer: buffer, offset: offset} = offset_buffer, position, count) do
    {result, buffer} = Buffer.random(buffer, offset + position, count)
    {result, struct!(offset_buffer, buffer: buffer)}
  end

  def tell(%__MODULE__{buffer: buffer, offset: offset}) do
    buffer.position - offset
  end
end
