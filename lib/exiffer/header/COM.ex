defmodule Exiffer.Header.COM do
  @moduledoc """
  Documentation for `Exiffer.Header.COM`.
  """

  alias Exiffer.{Binary, Buffer}
  require Logger

  @enforce_keys ~w(comment)a
  defstruct ~w(comment)a

  defimpl Jason.Encoder  do
    @spec encode(%Exiffer.Header.COM{}, Jason.Encode.opts()) :: String.t()
    def encode(entry, opts) do
      Jason.Encode.map(
        %{
          module: "Exiffer.Header.COM",
          comment: entry.comment
        },
        opts
      )
    end
  end

  def new(%{data: <<0xff, 0xfe, length_binary::binary-size(2), _rest::binary>>} = buffer) do
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

  def binary(%__MODULE__{} = com) do
    length = byte_size(com.comment)
    length_binary = Binary.int16u_to_big_endian(2 + length)
    <<0xff, 0xfe, length_binary::binary, com.comment::binary>>
  end

  def write(%__MODULE__{} = com, io_device) do
    Logger.debug "Writing COM header"
    binary = binary(com)
    :ok = IO.binwrite(io_device, binary)
  end

  defimpl Exiffer.Serialize do
    def write(com, io_device) do
      Exiffer.Header.COM.write(com, io_device)
    end

    def binary(com) do
      Exiffer.Header.COM.binary(com)
    end

    def puts(com) do
      Exiffer.Header.COM.puts(com)
    end
  end
end
