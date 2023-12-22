defmodule Exiffer.JPEG.Header.COM do
  @moduledoc """
  Documentation for `Exiffer.JPEG.Header.COM`.
  """

  alias Exiffer.Binary
  require Logger

  @enforce_keys ~w(comment)a
  defstruct ~w(comment)a

  defimpl Jason.Encoder  do
    @spec encode(%Exiffer.JPEG.Header.COM{}, Jason.Encode.opts()) :: String.t()
    def encode(entry, opts) do
      Jason.Encode.map(
        %{
          module: "Exiffer.JPEG.Header.COM",
          comment: entry.comment
        },
        opts
      )
    end
  end

  def new(%{data: <<0xff, 0xfe, length_binary::binary-size(2), _rest::binary>>} = buffer) do
    buffer = Exiffer.Buffer.skip(buffer, 4)
    length = Binary.big_endian_to_integer(length_binary)
    # Remove 2 bytes for length
    text_length = length - 2
    {comment, buffer} = Exiffer.Buffer.consume(buffer, text_length)
    if :binary.last(comment) == 0 do
      :binary.part(comment, {0, text_length - 1})
    else
      comment
    end
    com = %__MODULE__{comment: comment}
    {:ok, com, buffer}
  end

  def text(%__MODULE__{} = com) do
    """
    Comment
    -------
    Comment: #{com.comment}
    """
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
    alias Exiffer.JPEG.Header.COM

    def write(com, io_device) do
      COM.write(com, io_device)
    end

    def binary(com) do
      COM.binary(com)
    end

    def text(com) do
      COM.text(com)
    end
  end
end
