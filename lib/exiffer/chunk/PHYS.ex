defmodule Exiffer.Chunk.PHYS do
  defstruct ~w(x_pixels_per_unit y_pixels_per_unit unit)a

  alias Exiffer.Binary

  def new(<<x_binary::binary-size(4), y_binary::binary-size(4), unit_byte>>) do
    x = Binary.to_integer(x_binary)
    y = Binary.to_integer(y_binary)
    unit =
      case unit_byte do
        0 ->
          :unknown

        1 ->
          :meter
      end
      %__MODULE__{x_pixels_per_unit: x, y_pixels_per_unit: y, unit: unit}
  end
end
