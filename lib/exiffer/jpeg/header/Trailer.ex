defmodule Exiffer.JPEG.Header.Trailer do
  @moduledoc """
  A struct that holds binary data after the `EOI`
  """

  alias Exiffer.Buffer

  require Logger

  defstruct ~w(data)a

  def new(%{} = buffer) do
    {data, buffer} = Buffer.read_eof(buffer)
    trailer = %__MODULE__{data: data}
    {:ok, trailer, buffer}
  end

  def binary(%__MODULE__{data: data}), do: data

  def text(%__MODULE__{}) do
    """
    Trailer
    -------
    """
  end

  def write(%__MODULE__{data: data}, io_device) do
    Logger.debug("Writing trailer")
    :ok = IO.binwrite(io_device, data)
  end

  defimpl Exiffer.Serialize do
    alias Exiffer.JPEG.Header.Trailer

    def binary(trailer) do
      Trailer.binary(trailer)
    end

    def text(trailer) do
      Trailer.text(trailer)
    end

    def write(trailer, io_device) do
      Trailer.write(trailer, io_device)
    end
  end

  defimpl Jason.Encoder do
    @spec encode(%Exiffer.JPEG.Header.Trailer{}, Jason.Encode.opts()) :: String.t()
    def encode(entry, opts) do
      Logger.debug("Encoding Data")

      Jason.Encode.map(
        %{
          module: "Exiffer.JPEG.Header.Trailer",
          data: "(#{byte_size(entry.data)} bytes)"
        },
        opts
      )
    end
  end
end
