defmodule Exiffer.Header.COM do
  @moduledoc """
  Documentation for `Exiffer.Header.COM`.
  """

  alias Exiffer.Binary
  alias Exiffer.Buffer
  require Logger

  @enforce_keys ~w(comment)a
  defstruct ~w(comment)a

  def new(%Buffer{data: <<0xff, 0xfe, length_binary::binary-size(2), _rest::binary>>} = buffer) do
    buffer = Buffer.skip(buffer, 4)
    length = Binary.big_endian_to_integer(length_binary)
    # Remove 2 bytes for length
    text_length = length - 2
    {comment, buffer} = Buffer.consume(buffer, text_length)
    if :binary.last(comment) == 0 do
      :binary.part(comment, {0, text_length - 1})
    else
      comment
    end
    com = %__MODULE__{comment: comment}
    {com, buffer}
  end

  def puts(%__MODULE__{} = com) do
    IO.puts "Comment"
    IO.puts "-------"
    IO.puts "Comment: #{com.comment}"
  end

  defimpl Exiffer.Serialize do
    def write(_com, _io_device) do
    end

    def binary(_com) do
      <<>>
    end

    def puts(com) do
      Exiffer.Header.COM.puts(com)
    end
  end
end
