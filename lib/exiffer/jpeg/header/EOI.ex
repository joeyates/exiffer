defmodule Exiffer.JPEG.Header.EOI do
  @moduledoc """
  Documentation for `Exiffer.JPEG.Header.EOI`.
  """

  alias Exiffer.Buffer
  require Logger

  defstruct ~w()a

  defimpl Jason.Encoder  do
    @spec encode(%Exiffer.JPEG.Header.EOI{}, Jason.Encode.opts()) :: String.t()
    def encode(_entry, opts) do
      Jason.Encode.map(
        %{module: "Exiffer.JPEG.Header.EOI"},
        opts
      )
    end
  end

  def new(%{data: <<0xff, 0xd9, rest::binary>>} = buffer) do
    if rest != <<>> do
      Logger.warning("Found #{byte_size(rest)} trailing bytes after end of image")
    end
    buffer = Buffer.skip(buffer, 2)
    eoi = %__MODULE__{}
    {:ok, eoi, buffer}
  end

  def binary(%__MODULE__{}) do
    <<0xff, 0xd9>>
  end

  def text(%__MODULE__{}) do
    """
    EOI
    ---
    """
  end

  def write(%__MODULE__{} = data, io_device) do
    Logger.debug "Writing EOI header"
    binary = binary(data)
    :ok = IO.binwrite(io_device, binary)
  end

  defimpl Exiffer.Serialize do
    alias Exiffer.JPEG.Header.EOI

    def binary(data) do
      EOI.binary(data)
    end

    def text(data) do
      EOI.text(data)
    end

    def write(data, io_device) do
      EOI.write(data, io_device)
    end
  end
end
