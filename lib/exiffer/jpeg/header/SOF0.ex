defmodule Exiffer.JPEG.Header.SOF0 do
  @moduledoc """
  Documentation for `Exiffer.JPEG.Header.SOF0`.
  """

  alias Exiffer.Binary
  require Logger

  @enforce_keys ~w(bits_per_sample width height color_components_count components)a
  defstruct ~w(
    bits_per_sample
    width
    height
    color_components_count
    components
    encoding_process
    y_cb_cr_sub_sampling
  )a

  defimpl Jason.Encoder  do
    @spec encode(%Exiffer.JPEG.Header.SOF0{}, Jason.Encode.opts()) :: String.t()
    def encode(entry, opts) do
      Logger.debug("Encoding SOF0")
      Jason.Encode.map(
        %{
          module: "Exiffer.JPEG.Header.SOF0",
          bits_per_sample: entry.bits_per_sample,
          width: entry.width,
          height: entry.height,
          color_components_count: entry.color_components_count,
          components: "(#{byte_size(entry.components)} bytes)"
        },
        opts
      )
    end
  end

  def new(%{data: <<0xFF, 0xC0, _rest::binary>>} = buffer) do
    buffer = Exiffer.Buffer.skip(buffer, 4)

    {<<bits, height_binary::binary-size(2), width_binary::binary-size(2)>>, buffer} =
      Exiffer.Buffer.consume(buffer, 5)

    width = Binary.to_integer(width_binary)
    height = Binary.to_integer(height_binary)
    {<<color_components_count>>, buffer} = Exiffer.Buffer.consume(buffer, 1)
    components_length = color_components_count * 3

    {<<components::binary-size(components_length)>>, buffer} =
      Exiffer.Buffer.consume(buffer, components_length)

    <<_lead::binary-size(2), encoding_process, _rest::binary>> = components

    y_cb_cr_sub_sampling =
      if color_components_count == 3 do
        <<_lead1::binary-size(5), sub1, _lead2::binary-size(2), sub2>> = components
        {sub1, sub2}
      else
        nil
      end

    sof0 = %__MODULE__{
      bits_per_sample: bits,
      width: width,
      height: height,
      color_components_count: color_components_count,
      encoding_process: encoding_process,
      components: components,
      y_cb_cr_sub_sampling: y_cb_cr_sub_sampling
    }

    {:ok, sof0, buffer}
  end

  def text(%__MODULE__{} = sof0) do
    sub =
    if sof0.y_cb_cr_sub_sampling do
      {sub1, sub2} = sof0.y_cb_cr_sub_sampling
      "\nY Cb Cr Sub Sampling: #{sub1} #{sub2}"
    else
      ""
    end

    """
    Start of Frame 0 - Baseline DCT
    -------------------------------
    Bits per sample: #{sof0.bits_per_sample}
    Width: #{sof0.width}
    Height: #{sof0.height}
    Color components: #{sof0.color_components_count}
    Encoding process: #{sof0.encoding_process}#{sub}
    """
  end

  def binary(sof0) do
    height_binary = Binary.int16u_to_big_endian(sof0.height)
    width_binary = Binary.int16u_to_big_endian(sof0.width)

    bytes = <<
      sof0.bits_per_sample,
      height_binary::binary,
      width_binary::binary,
      sof0.color_components_count,
      sof0.components::binary
    >>

    length = byte_size(bytes)
    length_binary = Binary.int16u_to_big_endian(2 + length)
    <<0xFF, 0xC0, length_binary::binary, bytes::binary>>
  end

  def write(sof0, io_device) do
    Logger.debug("Writing SOF0 header")
    binary = binary(sof0)
    :ok = IO.binwrite(io_device, binary)
  end

  defimpl Exiffer.Serialize do
    alias Exiffer.JPEG.Header.SOF0

    def write(sof0, io_device) do
      SOF0.write(sof0, io_device)
    end

    def binary(sof0) do
      SOF0.binary(sof0)
    end

    def text(sof0) do
      SOF0.text(sof0)
    end
  end
end
