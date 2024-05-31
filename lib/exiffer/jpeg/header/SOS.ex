defmodule Exiffer.JPEG.Header.SOS do
  @moduledoc """
  Documentation for `Exiffer.JPEG.Header.SOS`.
  """

  alias Exiffer.IO.Buffer
  require Logger

  defstruct ~w(data)a

  defimpl Jason.Encoder  do
    @spec encode(%Exiffer.JPEG.Header.SOS{}, Jason.Encode.opts()) :: String.t()
    def encode(_entry, opts) do
      Jason.Encode.map(
        %{module: "Exiffer.JPEG.Header.SOS"},
        opts
      )
    end
  end

  def new(%{data: <<0xff, 0xda, _rest::binary>>} = buffer) do
    buffer = Buffer.skip(buffer, 2)
    {data, buffer} = read_data(buffer)
    {:ok, %__MODULE__{data: data}, buffer}
  end

  def binary(%__MODULE__{} = sos) do
    <<0xff, 0xda, sos.data::binary>>
  end

  def text(%__MODULE__{}) do
    """
    SOS
    ---
    """
  end

  def write(%__MODULE__{} = data, io_device) do
    Logger.debug "Writing SOS header"
    binary = binary(data)
    :ok = IO.binwrite(io_device, binary)
  end

  @chunk_size 4096

  # Read into the buffer until we find the end of SOS marker
  defp read_data(buffer, search_start \\ 0) do
    search_length = buffer.remaining - search_start
    case :binary.match(buffer.data, [<<0xff, 0xd9>>], scope: {search_start, search_length}) do
      {start, _length} ->
        Buffer.consume(buffer, start)
      :nomatch ->
        if buffer.status == :eof do
          Buffer.consume(buffer, buffer.remaining)
        else
          new_length = buffer.remaining + @chunk_size
          new_start = buffer.remaining
          buffer = Buffer.ensure(buffer, new_length)
          read_data(buffer, new_start)
        end
    end
  end

  defimpl Exiffer.Serialize do
    alias Exiffer.JPEG.Header.SOS

    def binary(data) do
      SOS.binary(data)
    end

    def text(data) do
      SOS.text(data)
    end

    def write(data, io_device) do
      SOS.write(data, io_device)
    end
  end
end
