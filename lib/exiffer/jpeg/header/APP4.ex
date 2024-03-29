defmodule Exiffer.JPEG.Header.APP4 do
  @moduledoc """
  Documentation for `Exiffer.JPEG.Header.APP4`.
  """

  alias Exiffer.Binary
  require Logger

  @enforce_keys ~w(value)a
  defstruct ~w(value)a

  defimpl Jason.Encoder  do
    @spec encode(%Exiffer.JPEG.Header.APP4{}, Jason.Encode.opts()) :: String.t()
    def encode(entry, opts) do
      Jason.Encode.map(
        %{
          module: "Exiffer.JPEG.Header.APP4",
          value: "(#{byte_size(entry.value)} bytes)",
        },
        opts
      )
    end
  end

  def new(%{data: <<0xff, 0xe4, _rest::binary>>} = buffer) do
    buffer = Exiffer.Buffer.skip(buffer, 2)
    {<<length_bytes::binary-size(2)>>, buffer} = Exiffer.Buffer.consume(buffer, 2)
    length = Binary.big_endian_to_integer(length_bytes)
    {value, buffer} = Exiffer.Buffer.consume(buffer, length - 2)
    app4 = %__MODULE__{value: value}
    {:ok, app4, buffer}
  end

  def binary(%__MODULE__{value: value}) do
    length = byte_size(value)
    length_binary = Binary.int16u_to_big_endian(2 + length)
    <<0xff, 0xe4, length_binary::binary, value::binary>>
  end

  def text(%__MODULE__{value: value}) do
    length = byte_size(value)
    """
    APP4
    ----
    value: #{length} bytes
    """
  end

  def write(%__MODULE__{} = data, io_device) do
    Logger.debug "Writing APP4 header"
    binary = binary(data)
    :ok = IO.binwrite(io_device, binary)
  end

  defimpl Exiffer.Serialize do
    alias Exiffer.JPEG.Header.APP4

    def binary(data) do
      APP4.binary(data)
    end

    def text(data) do
      APP4.text(data)
    end

    def write(data, io_device) do
      APP4.write(data, io_device)
    end
  end
end
