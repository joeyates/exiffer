defmodule Exiffer.Header.SOF0 do
  @moduledoc """
  Documentation for `Exiffer.Header.SOF0`.
  """

  alias Exiffer.Binary
  alias Exiffer.Buffer
  require Logger

  @enforce_keys ~w(bits_per_sample width height color_components)a
  defstruct ~w(
    bits_per_sample
    width
    height
    color_components
    encoding_process
    y_cb_cr_sub_sampling
  )a

  def new(%Buffer{data: <<0xff, 0xc0, _rest::binary>>} = buffer) do
    buffer = Buffer.skip(buffer, 4)
    {<<bits, height_binary::binary-size(2), width_binary::binary-size(2)>>, buffer} = Buffer.consume(buffer, 5)
    width = Binary.to_integer(width_binary)
    height = Binary.to_integer(height_binary)
    {<<color_components>>, buffer} = Buffer.consume(buffer, 1)
    components_length = color_components * 3
    {<<components::binary-size(components_length)>>, buffer} = Buffer.consume(buffer, components_length)
    <<_lead::binary-size(2), encoding_process, _rest::binary>> = components

    y_cb_cr_sub_sampling = if color_components == 3 do
      <<_lead1::binary-size(5), sub1, _lead2::binary-size(2), sub2>> = components
      {sub1, sub2}
    else
      nil
    end

    sof0 = %__MODULE__{
      bits_per_sample: bits,
      width: width,
      height: height,
      color_components: color_components,
      encoding_process: encoding_process,
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
    IO.puts "Color components: #{sof0.color_components}"
    IO.puts "Encoding process: #{sof0.encoding_process}"
    if sof0.y_cb_cr_sub_sampling do
      {sub1, sub2} = sof0.y_cb_cr_sub_sampling
      IO.puts "Y Cb Cr Sub Sampling: #{sub1} #{sub2}"
    end
  end

  defimpl Exiffer.Serialize do
    def write(_sof0, _io_device) do
    end

    def binary(_sof0) do
      <<>>
    end

    def puts(sof0) do
      Exiffer.Header.SOF0.puts(sof0)
    end
  end
end
