defmodule Exiffer.Header.SOS do
  @moduledoc """
  Documentation for `Exiffer.Header.SOS`.
  """

  alias Exiffer.Buffer
  require Logger

  defstruct ~w()a

  defimpl Jason.Encoder  do
    @spec encode(%Exiffer.Header.SOS{}, Jason.Encode.opts()) :: String.t()
    def encode(_entry, opts) do
      Jason.Encode.map(
        %{module: "Exiffer.Header.SOS"},
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

  def puts(%__MODULE__{}) do
    IO.puts "SOS"
    IO.puts "---"
  end

  def write(%__MODULE__{} = data, io_device) do
    Logger.debug "Writing SOS header"
    binary = binary(data)
    :ok = IO.binwrite(io_device, binary)
  end

  defimpl Exiffer.Serialize do
    def binary(data) do
      Exiffer.Header.SOS.binary(data)
    end

    def puts(data) do
      Exiffer.Header.SOS.puts(data)
    end

    def write(data, io_device) do
      Exiffer.Header.SOS.write(data, io_device)
    end
  end
end
