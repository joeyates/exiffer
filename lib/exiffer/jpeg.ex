defmodule Exiffer.JPEG do
  @moduledoc """
  Documentation for `Exiffer.JPEG`.
  """

  require Logger

  alias Exiffer.Binary
  alias Exiffer.JPEG.Header.{APP1, APP4, COM, Data, EOI, JFIF, SOF0, SOS}
  alias Exiffer.JPEG.Header.APP1.EXIF
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

  defp headers(%{data: <<0xff, 0xe1, _rest::binary>>} = buffer, headers) do
    Logger.debug "Reading APP1 header at #{integer(buffer.position)}"
    {:ok, app1, buffer} = APP1.new(buffer)
    headers(buffer, [app1 | headers])
  end

  defp headers(%{data: <<0xff, 0xe4, _rest::binary>>} = buffer, headers) do
    Logger.debug "Reading APP4 header at #{integer(buffer.position)}"
    {:ok, app4, buffer} = APP4.new(buffer)
    headers(buffer, [app4 | headers])
  end

  defp headers(%{data: <<0xff, 0xfe, _rest::binary>>} = buffer, headers) do
    Logger.debug "Reading COM header at #{integer(buffer.position)}"
    {:ok, comment, buffer} = COM.new(buffer)
    headers(buffer, [comment | headers])
  end

  defp headers(%{data: <<0xff, 0xe0, _length::binary-size(2), "JFIF", 0x00, _rest::binary>>} = buffer, headers) do
    Logger.debug "Reading JFIF header at #{integer(buffer.position)}"
    {:ok, jfif, buffer} = JFIF.new(buffer)
    headers(buffer, [jfif | headers])
  end

  defp headers(%{data: <<0xff, 0xc0, _rest::binary>>} = buffer, headers) do
    Logger.debug "Reading SOF0 header at #{integer(buffer.position)}"
    {:ok, sof0, buffer} = SOF0.new(buffer)
    headers(buffer, [sof0 | headers])
  end

  defp headers(%{data: <<0xff, 0xd9, _rest::binary>>} = buffer, headers) do
    Logger.debug "Reading EOI header at #{integer(buffer.position)}"
    {:ok, eoi, buffer} = EOI.new(buffer)
    {buffer, [eoi | headers]}
  end

  defp headers(%{data: <<0xff, 0xda, _rest::binary>>} = buffer, headers) do
    Logger.debug "Reading SOS header at #{integer(buffer.position)}"
    {:ok, sos, buffer} = SOS.new(buffer)
    headers(buffer, [sos | headers])
  end

  defp headers(%{} = buffer, headers) do
    Logger.debug "Reading generic data header at #{integer(buffer.position)}"
    {:ok, header, buffer} = Data.new(buffer)
    headers(buffer, [header | headers])
  end

  def dimensions(%__MODULE__{} = jpeg) do
    sof0_dimensions(jpeg) || exif_dimensions(jpeg)
  end

  defp sof0_dimensions(%__MODULE__{} = jpeg) do
    case sof0(jpeg) do
      nil -> nil
      sof0 -> SOF0.dimensions(sof0)
    end
  end

  defp exif_dimensions(%__MODULE__{} = jpeg) do
    case exif(jpeg) do
      nil -> nil
      exif -> EXIF.dimensions(exif)
    end
  end

  defp sof0(%__MODULE__{} = jpeg) do
    jpeg.headers
    |> Enum.find(& &1.__struct__ == SOF0)
  end

  defp exif(%__MODULE__{} = jpeg) do
    jpeg.headers
    |> Enum.find(& &1.__struct__ == EXIF)
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
