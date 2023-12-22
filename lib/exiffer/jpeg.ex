defmodule Exiffer.JPEG do
  @moduledoc """
  Documentation for `Exiffer.JPEG`.
  """

  require Logger

  alias Exiffer.Binary
  alias Exiffer.JPEG.Header.{APP1, APP4, COM, Data, JFIF, SOF0, SOS}
  import Exiffer.Logging, only: [integer: 1]

  @enforce_keys ~w(headers)a
  defstruct ~w(headers)a

  defimpl Jason.Encoder  do
    @spec encode(%Exiffer.JPEG{}, Jason.Encode.opts()) :: String.t()
    def encode(entry, opts) do
      Jason.Encode.map(
        %{
          module: "Exiffer.JPEG",
          headers: entry.headers
        },
        opts
      )
    end
  end

  @magic <<0xff, 0xd8>>

  def magic, do: @magic

  def new(%{data: <<@magic, _rest::binary>>} = buffer) do
    buffer = Exiffer.Buffer.skip(buffer, 2)
    Logger.debug "JPEG.new/1 - setting initial byte order to :big"
    Binary.set_byte_order(:big)
    {%{} = buffer, headers} = headers(buffer, [])
    {%__MODULE__{headers: Enum.reverse(headers)}, buffer}
  end

  def binary(%__MODULE__{} = jpeg) do
    Logger.info "Exiffer.JPEG creating binary"
    Exiffer.Serialize.binary(jpeg.headers)
  end

  def text(%__MODULE__{} = jpeg) do
    Exiffer.Serialize.text(jpeg.headers)
  end

  def write(%__MODULE__{} = jpeg, io_device) do
    Logger.info "Exiffer.JPEG writing binary"
    :ok = IO.binwrite(io_device, @magic)
    :ok = Exiffer.Serialize.write(jpeg.headers, io_device)
  end

  defp headers(buffer, headers)

  defp headers(%{data: <<0xff, 0xc0, _rest::binary>>} = buffer, headers) do
    Logger.debug "Reading SOF0 header at #{Integer.to_string(buffer.position, 16)}"
    {sof0, buffer} = SOF0.new(buffer)
    {buffer, [sof0 | headers]}
  end

  defp headers(%{data: <<0xff, 0xda, _rest::binary>>} = buffer, headers) do
    Logger.debug "Reading SOS header at #{Integer.to_string(buffer.position, 16)}"
    {sos, buffer} = SOS.new(buffer)
    {buffer, [sos | headers]}
  end

  defp headers(%{data: <<0xff, 0xe0, _length::binary-size(2), "JFIF", 0x00, _rest::binary>>} = buffer, headers) do
    Logger.debug "Reading JFIF header at #{integer(buffer.position)}"
    {jfif, buffer} = JFIF.new(buffer)
    headers(buffer, [jfif | headers])
  end

  defp headers(%{data: <<0xff, 0xe1, _rest::binary>>} = buffer, headers) do
    Logger.debug "Reading APP1 header at #{Integer.to_string(buffer.position, 16)}"
    {app1, buffer} = APP1.new(buffer)
    headers(buffer, [app1 | headers])
  end

  defp headers(%{data: <<0xff, 0xe4, _rest::binary>>} = buffer, headers) do
    Logger.debug "Reading APP4 header at #{Integer.to_string(buffer.position, 16)}"
    {app4, buffer} = APP4.new(buffer)
    headers(buffer, [app4 | headers])
  end

  defp headers(%{data: <<0xff, 0xfe, _rest::binary>>} = buffer, headers) do
    Logger.debug "Reading COM header at #{Integer.to_string(buffer.position, 16)}"
    {comment, buffer} = COM.new(buffer)
    headers(buffer, [comment | headers])
  end

  defp headers(%{} = buffer, headers) do
    Logger.debug "Reading generic data header at #{integer(buffer.position)}"
    {header, buffer} = Data.new(buffer)
    headers(buffer, [header | headers])
  end

  defimpl Exiffer.Serialize do
    def write(%Exiffer.JPEG{} = jpeg, io_device) do
      Exiffer.JPEG.write(jpeg, io_device)
    end

    def binary(jpeg) do
      Exiffer.JPEG.binary(jpeg)
    end

    def text(%Exiffer.JPEG{} = jpeg) do
      Exiffer.JPEG.text(jpeg)
    end
  end
end
