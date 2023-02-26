defmodule Exiffer.JPEG do
  @moduledoc """
  Documentation for `Exiffer.JPEG`.
  """

  alias Exiffer.{Binary, Buffer}
  alias Exiffer.Header.APP1
  alias Exiffer.Header.APP4
  alias Exiffer.Header.COM
  alias Exiffer.Header.Data
  alias Exiffer.Header.JFIF
  alias Exiffer.Header.SOF0
  alias Exiffer.Header.SOS
  require Logger

  @enforce_keys ~w(headers)a
  defstruct ~w(headers)a

  @magic <<0xff, 0xd8>>

  def magic, do: @magic

  def new(%{data: <<@magic, _rest::binary>>} = buffer) do
    buffer = Buffer.skip(buffer, 2)
    Binary.set_byte_order(:big)
    {%{} = buffer, headers} = headers(buffer, [])
    {%__MODULE__{headers: headers}, buffer}
  end

  def puts(%__MODULE__{} = jpeg) do
    :ok = Exiffer.Serialize.puts(jpeg.headers)
  end

  def binary(%__MODULE__{} = jpeg) do
    Exiffer.Serialize.binary(jpeg.headers)
  end

  def write(%__MODULE__{} = jpeg, io_device) do
    :ok = Exiffer.Serialize.write(jpeg.headers, io_device)
  end

  defp headers(buffer, headers)

  defp headers(%{data: <<0xff, 0xc0, _rest::binary>>} = buffer, headers) do
    {sof0, buffer} = SOF0.new(buffer)
    headers = Enum.reverse([sof0 | headers])
    {buffer, headers}
  end

  defp headers(%{data: <<0xff, 0xda, _rest::binary>>} = buffer, headers) do
    {sos, buffer} = SOS.new(buffer)
    headers = Enum.reverse([sos | headers])
    {buffer, headers}
  end

  defp headers(%{data: <<0xff, 0xe0, _rest::binary>>} = buffer, headers) do
    Logger.debug ~s(Header "JFIF" at #{Integer.to_string(buffer.position, 16)})
    {jfif, buffer} = JFIF.new(buffer)
    headers(buffer, [jfif | headers])
  end

  defp headers(%{data: <<0xff, 0xe1, _rest::binary>>} = buffer, headers) do
    Logger.debug ~s(Header "APP1" at #{Integer.to_string(buffer.position, 16)})
    {app1, buffer} = APP1.new(buffer)
    headers(buffer, [app1 | headers])
  end

  defp headers(%{data: <<0xff, 0xe4, _rest::binary>>} = buffer, headers) do
    Logger.debug ~s(Header "APP4" at #{Integer.to_string(buffer.position, 16)})
    {app4, buffer} = APP4.new(buffer)
    headers(buffer, [app4 | headers])
  end

  defp headers(%{data: <<0xff, 0xfe, _rest::binary>>} = buffer, headers) do
    Logger.debug ~s(Header "COM" at #{Integer.to_string(buffer.position, 16)})
    {comment, buffer} = COM.new(buffer)
    headers(buffer, [comment | headers])
  end

  defp headers(%{} = buffer, headers) do
    Logger.debug ~s(Header Data at #{Integer.to_string(buffer.position, 16)})
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

    def puts(%Exiffer.JPEG{} = jpeg) do
      Exiffer.JPEG.puts(jpeg)
    end
  end
end
