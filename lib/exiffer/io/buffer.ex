defmodule Exiffer.IO.Buffer do
  @moduledoc """
  Documentation for `Exiffer.IO.Buffer`.

  A buffer with read access to the file source.

  When matching on the buffer's raw data, it is up to the user to use ensure/2
  so that enough data has been read.
  """

  require Logger

  @enforce_keys ~w(io_device)a
  defstruct [
    :io_device,
    data: <<>>,
    position: 0,
    remaining: 0,
    read_ahead: 1000,
    status: :ok
  ]

  def offset_buffer(buffer, offset) do
    Exiffer.OffsetBuffer.new(buffer, offset)
  end

  def new_from_binary(binary, opts \\ []) do
    direction = Keyword.get(opts, :direction, :read)
    {:ok, fd} = :file.open(binary, [:ram, :binary, direction])

    initialize(fd, opts)
  end

  def new(filename, opts \\ []) do
    direction = Keyword.get(opts, :direction, :read)
    open_opts = [:binary, direction]
    {:ok, fd} = File.open(filename, open_opts)

    initialize(fd, opts)
  end

  defp initialize(fd, opts) do
    direction = Keyword.get(opts, :direction, :read)
    read_ahead = Keyword.get(opts, :read_ahead, 1000)
    buffer = %__MODULE__{io_device: fd, read_ahead: read_ahead}
    if direction == :read do
      ensure(buffer, read_ahead)
    else
      buffer
    end
  end

  def seek(%__MODULE__{io_device: io_device} = buffer, position) do
    finish = buffer.position + buffer.remaining

    {data, remaining} =
      if position >= buffer.position && position < finish do
        count = position - buffer.position
        <<_skip::binary-size(count), rest::binary>> = buffer.data
        remaining = buffer.remaining - count
        correct_position = position + remaining
        {:ok, _position} = :file.position(io_device, correct_position)
        {rest, remaining}
      else
        {:ok, _position} = :file.position(io_device, position)
        {<<>>, 0}
      end

    struct!(buffer, data: data, position: position, remaining: remaining)
    |> ensure(buffer.read_ahead)
  end

  def consume(%__MODULE__{} = buffer, count) do
    %__MODULE__{data: data, position: position, remaining: remaining} =
      buffer = ensure(buffer, count)

    available = if remaining >= count, do: count, else: remaining
    <<consumed::binary-size(available), rest::binary>> = data
    new_position = position + available

    buffer =
      struct!(buffer, data: rest, position: new_position, remaining: remaining - available)
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
  def random(buffer, read_position, count)

  def random(
        %__MODULE__{data: data, position: position, remaining: remaining},
        read_position,
        count
      )
      when read_position > position and read_position + count < position + remaining do
    start = read_position - position
    <<_before::binary-size(start), result::binary-size(count), _rest::binary>> = data
    result
  end

  def random(%__MODULE__{} = buffer, read_position, count) do
    %__MODULE__{io_device: io_device, position: position, remaining: remaining} = buffer
    {:ok, _position} = :file.position(io_device, read_position)

    result =
      case IO.binread(io_device, count) do
        :eof ->
          nil

        chunk ->
          chunk
      end

    end_of_current_buffer = position + remaining
    {:ok, _position} = :file.position(io_device, end_of_current_buffer)
    result
  end

  def tell(buffer), do: buffer.position

  @copy_chunk_size 1_000_000

  def copy(%__MODULE__{} = input, %__MODULE__{} = output) do
    case consume(input, @copy_chunk_size) do
      {<<chunk::binary-size(@copy_chunk_size)>>, input} ->
        length = byte_size(chunk)
        Logger.debug("#{__MODULE__}.copy/2 - chunk, #{length} bytes")
        :ok = write(output, chunk)
        copy(input, output)

      {chunk, _input} ->
        length = byte_size(chunk)
        Logger.debug("#{__MODULE__}.copy/2 - final chunk, #{length} bytes")
        :ok = write(output, chunk)
        nil
    end
  end

  def write(%__MODULE__{io_device: io_device}, binary) do
    :ok = IO.binwrite(io_device, binary)
  end

  def close(%__MODULE__{io_device: io_device}) do
    :ok = File.close(io_device)
  end

  def ensure(%__MODULE__{remaining: remaining} = buffer, amount)
  when remaining > amount do
    buffer
  end

  def ensure(%__MODULE__{remaining: remaining, read_ahead: read_ahead} = buffer, amount) do
    new_length = max(amount, read_ahead)
    needed = new_length - remaining
    read(buffer, needed)
  end

  defp read(%__MODULE__{io_device: io_device, data: data, remaining: remaining} = buffer, amount) do
    case IO.binread(io_device, amount) do
      :eof ->
        Logger.debug("Buffer.read EOF")
        struct!(buffer, status: :eof)

      chunk ->
        bytes_read = byte_size(chunk)
        data = <<data::binary, chunk::binary>>
        struct!(buffer, data: data, remaining: remaining + bytes_read)
    end
  end

  defimpl Exiffer.Buffer do
    alias Exiffer.IO.Buffer

    def offset_buffer(buffer, offset) do
      Buffer.offset_buffer(buffer, offset)
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
