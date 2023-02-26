defmodule Exiffer.Header.SOF0 do
  @moduledoc """
  Documentation for `Exiffer.Header.SOF0`.
  """

  alias Exiffer.{Binary, Buffer}
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

  def new(%{data: <<0xff, 0xc0, _rest::binary>>} = buffer) do
    buffer = Buffer.skip(buffer, 4)
    {<<bits, height_binary::binary-size(2), width_binary::binary-size(2)>>, buffer} = Buffer.consume(buffer, 5)
    width = Binary.to_integer(width_binary)
    height = Binary.to_integer(height_binary)
    {<<color_components_count>>, buffer} = Buffer.consume(buffer, 1)
    components_length = color_components_count * 3
    {<<components::binary-size(components_length)>>, buffer} = Buffer.consume(buffer, components_length)
    <<_lead::binary-size(2), encoding_process, _rest::binary>> = components

    y_cb_cr_sub_sampling = if color_components_count == 3 do
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
    {sof0, buffer}
  end

  def puts(%__MODULE__{} = sof0) do
    IO.puts "Start of Frame 0 - Baseline DCT"
    IO.puts "-------------------------------"
    IO.puts "Bits per sample: #{sof0.bits_per_sample}"
    IO.puts "Width: #{sof0.width}"
    IO.puts "Height: #{sof0.height}"
    IO.puts "Color components: #{sof0.color_components_count}"
    IO.puts "Encoding process: #{sof0.encoding_process}"
    if sof0.y_cb_cr_sub_sampling do
      {sub1, sub2} = sof0.y_cb_cr_sub_sampling
      IO.puts "Y Cb Cr Sub Sampling: #{sub1} #{sub2}"
    end
  end

  def binary(sof0) do
    height_binary = Binary.int16u_to_big_endian(sof0.height)
    width_binary = Binary.int16u_to_big_endian(sof0.width)
    bytes = <<
      sof0.bits_per_sample, height_binary::binary, width_binary::binary,
      sof0.color_components_count,
      sof0.components::binary
    >>
    length = byte_size(bytes)
    length_binary = Binary.int16u_to_big_endian(2 + length)
    <<0xff, 0xc0, length_binary::binary, bytes::binary>>
  end

  def write(sof0, io_device) do
    Logger.debug "#{__MODULE__}.write/2"
    binary = binary(sof0)
    :ok = IO.binwrite(io_device, binary)
  end

  defimpl Exiffer.Serialize do
    def write(sof0, io_device) do
      Exiffer.Header.SOF0.write(sof0, io_device)
    end

    def binary(sof0) do
      Exiffer.Header.SOF0.binary(sof0)
    end

    def puts(sof0) do
      Exiffer.Header.SOF0.puts(sof0)
    end
  end
end
