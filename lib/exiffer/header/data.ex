defmodule Exiffer.Header.Data do
  @moduledoc """
  Documentation for `Exiffer.Header.Data`.
  """

  alias Exiffer.Binary
  alias Exiffer.Buffer

  @enforce_keys ~w(type data)a
  defstruct ~w(type data)a

  @type_name %{
    <<0xff, 0xc0>> => "JPEG SOF0",
    <<0xff, 0xc4>> => "JPEG DHT",
    <<0xff, 0xdd>> => "JPEG DRI", # Define Restart Interval
    <<0xff, 0xdb>> => "JPEG DQT",
    <<0xff, 0xe5>> => "APP5",
    <<0xff, 0xfe>> => "JPEG COM Comment"
  }

  def new(%Buffer{} = buffer) do
    {<<magic::binary-size(2), length_binary::binary-size(2)>>, buffer} = Buffer.consume(buffer, 4)
    type = @type_name[magic]
    if !type do
      raise "Unknown header magic #{inspect(magic, [base: :hex])} found"
    end
    length = Binary.big_endian_to_integer(length_binary)
    {data, buffer} = Buffer.consume(buffer, length - 2)
    header = %__MODULE__{type: type, data: data}
    {header, buffer}
  end
end
