defmodule Exiffer.PNG do
  @moduledoc """
  Documentation for `Exiffer.PNG`.
  """

  require Logger

  alias Exiffer.{Binary, Buffer}
  alias Exiffer.PNG.Chunk
  import Exiffer.Logging, only: [integer: 1]

  @enforce_keys ~w(chunks)a
  defstruct ~w(chunks)a

  @magic <<0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a>>

  def magic, do: @magic

  def new(%{data: <<@magic, _rest::binary>>} = buffer) do
    buffer = Buffer.skip(buffer, byte_size(@magic))
    Logger.debug "PNG.new/1"
    Binary.set_byte_order(:big)
    {buffer, chunks} = chunks(buffer, [])
    {%__MODULE__{chunks: chunks}, buffer}
  end

  defp chunks(%{data: <<>>} = buffer, chunks), do: {buffer, Enum.reverse(chunks)}

  defp chunks(%{data: <<length_binary::binary-size(4), type::binary-size(4), _rest::binary>>} = buffer, chunks) do
    Logger.debug "Reading chunk at #{integer(buffer.position)}"
    length = Binary.to_integer(length_binary)
    buffer = Buffer.skip(buffer, 8)
    {<<data::binary-size(length)>>, buffer} = Buffer.consume(buffer, length)
    {<<_crc::binary-size(4)>>, buffer} = Buffer.consume(buffer, 4)
    chunk = Chunk.new(type, data)
    chunks(buffer, [chunk | chunks])
  end

  def binary(%__MODULE__{} = png) do
    Logger.info "Exiffer.PNG creating binary"
    Exiffer.Serialize.binary(png.chunks)
  end

  def text(%__MODULE__{} = png) do
    Exiffer.Serialize.text(png.chunks)
  end

  def write(%__MODULE__{} = png, io_device) do
    Logger.info "Exiffer.PNG writing binary"
    :ok = IO.binwrite(io_device, @magic)
    :ok = Exiffer.Serialize.write(png.chunks, io_device)
  end

  defimpl Exiffer.Serialize do
    alias Exiffer.PNG

    def write(%PNG{} = png, io_device) do
      PNG.write(png, io_device)
    end

    def binary(png) do
      PNG.binary(png)
    end

    def text(%PNG{} = png) do
      PNG.text(png)
    end
  end
end
