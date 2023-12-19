defmodule Exiffer.JPEG.Header.SOS do
  @moduledoc """
  Documentation for `Exiffer.JPEG.Header.SOS`.
  """

  alias Exiffer.Buffer
  require Logger

  defstruct ~w()a

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
    sos = %__MODULE__{}
    {sos, buffer}
  end

  def binary(%__MODULE__{}), do: <<0xff, 0xda>>

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
