defmodule Exiffer.Buffer do
  @moduledoc """
  Documentation for `Exiffer.Buffer`.

  A buffer with read access to the file source.

  When matching on the buffer's raw data, it is up to the user to use ensure/2
  so that enough data has been read.
  """

  defstruct [:io_device, data: <<>>, position: 0, remaining: 0, read_ahead: 1000]

  def new(filename, opts \\ []) do
    read_ahead = Keyword.get(opts, :read_ahead, 1000)
    {:ok, io_device} = File.open(filename)

    %__MODULE__{io_device: io_device, read_ahead: read_ahead}
    |> ensure(read_ahead)
  end

  def ensure(%__MODULE__{remaining: remaining} = buffer, amount) when remaining > amount, do: buffer

  def ensure(%__MODULE__{remaining: remaining, read_ahead: read_ahead} = buffer, amount) do
    new_length = max(amount, read_ahead)
    needed = new_length - remaining
    read(buffer, needed)
  end

  def seek(%__MODULE__{io_device: io_device} = buffer, position) do
    start = buffer.position
    finish = start + buffer.remaining
    {data, remaining} = if position >= start && position < finish do
      count = position - start
      <<_skip::binary-size(count), rest::binary>> = buffer.data
      remaining = buffer.remaining - count
      {rest, remaining}
    else
      {<<>>, 0}
    end
    {:ok, _position} = :file.position(io_device, position)

    struct!(buffer, data: data, position: position, remaining: remaining)
    |> ensure(buffer.read_ahead)
  end

  def consume(%__MODULE__{} = buffer, count) do
    buffer = ensure(buffer, count)
    %__MODULE__{data: data, position: position, remaining: remaining} = buffer = ensure(buffer, count)
    <<consumed::binary-size(count), rest::binary>> = data
    buffer =
      struct!(buffer, data: rest, position: position + count, remaining: remaining - count)
      |> ensure(buffer.read_ahead)

    {consumed, buffer}
  end

  def skip(%__MODULE__{} = buffer, count) do
    seek(buffer, buffer.position + count)
  end

  @doc """
  Read some bytes without changing the current buffer position.

  If the bytes are in the current read buffer, simply return them.
  Otherwise, position the buffer, read the bytes, then reposition the buffer
  to the previous position.
  """
  def random(%__MODULE__{data: data, position: position, remaining: remaining} = buffer, read_position, count) when read_position > position and (read_position + count) < (position + remaining) do
    start = read_position - position
    <<_before::binary-size(start), result::binary-size(count), _rest::binary>> = data
    {result, buffer}
  end

  def random(%__MODULE__{} = buffer, read_position, count) do
    %__MODULE__{io_device: io_device, position: position} = buffer
    {:ok, _position} = :file.position(io_device, read_position)
    result = case IO.binread(io_device, count) do
      :eof ->
        nil
      chunk ->
        chunk
    end
    {:ok, _position} = :file.position(io_device, position)
    {result, buffer}
  end

  def close(%__MODULE__{io_device: io_device}) do
    :ok = File.close(io_device)
  end

  defp read(%__MODULE__{io_device: io_device, data: data, remaining: remaining} = buffer, amount) do
    case IO.binread(io_device, amount) do
      :eof ->
        buffer
      chunk ->
        struct!(buffer, data: <<data::binary, chunk::binary>>, remaining: remaining + amount)
    end
  end
end
