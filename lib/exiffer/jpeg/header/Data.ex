defmodule Exiffer.JPEG.Header.Data do
  @moduledoc """
  Documentation for `Exiffer.JPEG.Header.Data`.
  """

  require Logger

  alias Exiffer.Binary
  import Exiffer.Logging, only: [integer: 1]

  @enforce_keys ~w(type data)a
  defstruct ~w(type data)a

  defimpl Jason.Encoder  do
    @spec encode(%Exiffer.JPEG.Header.Data{}, Jason.Encode.opts()) :: String.t()
    def encode(entry, opts) do
      Logger.debug("Encoding Data")
      Jason.Encode.map(
        %{
          module: "Exiffer.JPEG.Header.Data",
          type: entry.type,
          data: "(#{byte_size(entry.data)} bytes)",
        },
        opts
      )
    end
  end

  @data_type %{
    <<0xff, 0xc0>> => %{key: :jpeg_sof0, name: "JPEG SOF0"},
    <<0xff, 0xc2>> => %{key: :jpeg_sof2, name: "JPEG SOF2"},
    <<0xff, 0xc4>> => %{key: :jpeg_dht, name: "JPEG DHT"},
    <<0xff, 0xdd>> => %{key: :jpeg_dri, name: "JPEG DRI"}, # Define Restart Interval
    <<0xff, 0xdb>> => %{key: :jpeg_dqt, name: "JPEG DQT"},
    <<0xff, 0xe0>> => %{key: :jpeg_jfxx, name: "JPEG JFXX"},
    <<0xff, 0xe2>> => %{key: :jpeg_app2, name: "JPEG APP2"},
    <<0xff, 0xe3>> => %{key: :jpeg_app3, name: "JPEG APP3"},
    <<0xff, 0xe5>> => %{key: :jpeg_app5, name: "JPEG APP5"},
    <<0xff, 0xe6>> => %{key: :jpeg_app6, name: "JPEG APP6"},
    <<0xff, 0xe7>> => %{key: :jpeg_app7, name: "JPEG APP7"},
    <<0xff, 0xe8>> => %{key: :jpeg_app8, name: "JPEG APP8"},
    <<0xff, 0xe9>> => %{key: :jpeg_app9, name: "JPEG APP9"},
    <<0xff, 0xea>> => %{key: :jpeg_app10, name: "JPEG APP10"},
    <<0xff, 0xeb>> => %{key: :jpeg_app11, name: "JPEG APP11"},
    <<0xff, 0xec>> => %{key: :jpeg_app12, name: "JPEG APP12"},
    <<0xff, 0xed>> => %{key: :jpeg_app13, name: "JPEG APP13"},
    <<0xff, 0xee>> => %{key: :jpeg_app14, name: "JPEG APP14"},
    <<0xff, 0xef>> => %{key: :jpeg_app15, name: "JPEG APP15"},
    <<0xff, 0xfe>> => %{key: :jpeg_comment, name: "JPEG COM Comment"}
  }

  @magic Enum.into(@data_type, %{}, fn {magic, %{key: key}} -> {key, magic} end)

  def new(%{} = buffer) do
    position = buffer.position
    {<<magic::binary-size(2), length_binary::binary-size(2)>>, buffer} = Exiffer.Buffer.consume(buffer, 4)
    type = @data_type[magic]
    if !type do
      raise "Unknown header magic #{inspect(magic, [base: :hex])} found at #{integer(position)}"
    end
    # TODO: is this really always big endian?
    length = Binary.big_endian_to_integer(length_binary)
    {data, buffer} = Exiffer.Buffer.consume(buffer, length - 2)
    header = %__MODULE__{type: type.key, data: data}
    {header, buffer}
  end

  def binary(%__MODULE__{type: type, data: data}) do
    length = 2 + byte_size(data)
    binary_length = Binary.int16u_to_big_endian(length)
    <<
    @magic[type]::binary,
    binary_length::binary,
    data::binary
    >>
  end

  def text(%__MODULE__{type: type, data: data}) do
    length = byte_size(data)
    """
    Data
    ----
    type: #{type}
    data: #{length} bytes
    """
  end

  def write(%__MODULE__{type: type, data: data}, io_device) do
    Logger.debug "Writing generic data header, type: #{type}"
    magic = @magic[type]
    IO.binwrite(io_device, magic)
    length = 2 + byte_size(data)
    length_binary = Binary.int16u_to_big_endian(length)
    IO.binwrite(io_device, length_binary)
    IO.binwrite(io_device, data)
  end

  defimpl Exiffer.Serialize do
    alias Exiffer.JPEG.Header.Data

    def write(data, io_device) do
      Data.write(data, io_device)
    end

    def binary(data) do
      Data.binary(data)
    end

    def text(data) do
      Data.text(data)
    end
  end
end
