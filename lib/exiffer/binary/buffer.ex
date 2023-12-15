defmodule Exiffer.Binary.Buffer do
  @moduledoc """
  Documentation for `Exiffer.Binary.Buffer`.

  A wrapper for a blob of binary data
  """
  @enforce_keys ~w(data original size)a
  defstruct [:data, :original, :size, position: 0]

  def new(binary) do
    size = byte_size(binary)
    %__MODULE__{data: binary, original: binary, size: size}
  end

  def seek(%__MODULE__{original: original} = buffer, position) do
    <<_before::binary-size(position), rest::binary>> = original

    struct!(buffer, data: rest, position: position)
  end

  def consume(%__MODULE__{} = buffer, count) do
    remaining = buffer.size - buffer.position
    <<_before::binary-size(buffer.position), rest::binary>> = buffer.original
    available = if remaining >= count, do: count, else: remaining
    <<consumed::binary-size(available), data::binary>> = rest
    position = buffer.position + available
    buffer = struct!(buffer, data: data, position: position)

    {consumed, buffer}
  end

  def skip(%__MODULE__{} = buffer, count) do
    seek(buffer, buffer.position + count)
  end

  def tell(%__MODULE__{} = buffer) do
    buffer.position
  end

  def random(%__MODULE__{original: original}, read_position, count) do
    <<_before::binary-size(read_position), result::binary-size(count), _rest::binary>> = original
    result
  end

  def close(%__MODULE__{}), do: :ok

  defimpl Exiffer.Buffer do
    alias Exiffer.Binary.Buffer

    def offset_buffer(buffer, offset) do
      Exiffer.OffsetBuffer.new(buffer, offset)
    end

    def consume(buffer, count) do
      Buffer.consume(buffer, count)
    end

    def seek(buffer, position) do
      Buffer.seek(buffer, position)
    end

    def skip(buffer, count) do
      Buffer.skip(buffer, count)
    end

    def random(buffer, read_position, count) do
      Buffer.random(buffer, read_position, count)
    end

    def tell(buffer) do
      Buffer.tell(buffer)
    end
  end
end
