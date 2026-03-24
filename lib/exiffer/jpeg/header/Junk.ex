defmodule Exiffer.JPEG.Header.Junk do
  @moduledoc """
  Represents a chunk of data in a JPEG file that is not recognized as a specific header type.
  """

  alias Exiffer.Buffer

  @enforce_keys ~w(data)a
  defstruct ~w(data)a

  @chunk_size 1024

  def new(buffer) do
    # Collect bytes up to the next 0xFF byte, which indicates the start of the next header
    {data, buffer} =
      fn ->
        buffer
      end
      |> Stream.resource(
        fn
          :halt ->
            {:halt, nil}

          buffer ->
            {chunk, buffer} = Buffer.consume(buffer, @chunk_size)

            # We always return the updated buffer, so that we can pick the last
            # version to return
            case :binary.match(chunk, <<0xFF>>) do
              :nomatch ->
                {[{chunk, buffer}], buffer}

              {index, _length} ->
                <<before::binary-size(index)>> <> rest = chunk
                buffer = Buffer.push(buffer, rest)
                {[{before, buffer}], :halt}
            end
        end,
        fn _ ->
          nil
        end
      )
      |> Enum.reduce(
        {"", nil},
        fn {chunk, buffer}, {data, _previous_buffer} ->
          {data <> chunk, buffer}
        end
      )

    header = %__MODULE__{data: data}
    {:ok, header, buffer}
  end

  def binary(%__MODULE__{data: data}) do
    data
  end

  def text(%__MODULE__{data: data}) do
    length = byte_size(data)

    """
    Junk
    ----
    data: #{length} bytes
    """
  end

  def write(%__MODULE__{data: data}, io_device) do
    IO.binwrite(io_device, data)
  end

  defimpl Exiffer.Serialize do
    alias Exiffer.JPEG.Header.Junk

    def binary(%Junk{} = junk) do
      Junk.binary(junk)
    end

    def text(%Junk{} = junk) do
      Junk.text(junk)
    end

    def write(%Junk{} = junk, io_device) do
      Junk.write(junk, io_device)
    end
  end
end
