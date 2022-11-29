defmodule Exiffer.Header.Data do
  @moduledoc """
  Documentation for `Exiffer.Header.Data`.
  """

  alias Exiffer.Binary
  alias Exiffer.Buffer
  require Logger

  @enforce_keys ~w(type data)a
  defstruct ~w(type data)a

  @data_type %{
    <<0xff, 0xc0>> => %{key: :jpeg_sof0, name: "JPEG SOF0"},
    <<0xff, 0xc4>> => %{key: :jpeg_dht, name: "JPEG DHT"},
    <<0xff, 0xdd>> => %{key: :jpeg_dri, name: "JPEG DRI"}, # Define Restart Interval
    <<0xff, 0xdb>> => %{key: :jpeg_dqt, name: "JPEG DQT"},
    <<0xff, 0xe5>> => %{key: :jpeg_app5, name: "JPEG APP5"},
    <<0xff, 0xfe>> => %{key: :jpeg_comment, name: "JPEG COM Comment"}
  }

  @magic Enum.into(@data_type, %{}, fn {magic, %{key: key}} -> {key, magic} end)

  def new(%Buffer{} = buffer) do
    {<<magic::binary-size(2), length_binary::binary-size(2)>>, buffer} = Buffer.consume(buffer, 4)
    type = @data_type[magic]
    if !type do
      position = buffer.position
      raise "Unknown header magic #{inspect(magic, [base: :hex])} found at 0x#{Integer.to_string(position, 16)}"
    end
    # TODO: is this really always big endian?
    length = Binary.big_endian_to_integer(length_binary)
    {data, buffer} = Buffer.consume(buffer, length - 2)
    header = %__MODULE__{type: type.key, data: data}
    {header, buffer}
  end

  def write(%__MODULE__{type: type, data: data}, io_device) do
    Logger.info("Data.write, type: #{type}")
    magic = @magic[type]
    IO.binwrite(io_device, magic)
    length = 2 + byte_size(data)
    length_binary = Binary.int16u_to_big_endian(length)
    IO.binwrite(io_device, length_binary)
    IO.binwrite(io_device, data)
  end

  def binary(%__MODULE__{type: type, data: data}) do
    length = 2 + byte_size(data)
    <<
    @magic[type],
    Binary.int32u_to_big_endian(length),
    data
    >>
  end

  defimpl Exiffer.Serialize do
    def write(data, io_device) do
      Exiffer.Header.Data.write(data, io_device)
    end

    def binary(data) do
      Exiffer.Header.Data.binary(data)
    end

    def puts(_data) do
      :ok
    end
  end
end
