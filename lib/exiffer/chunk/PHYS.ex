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

  def binary(%__MODULE__{} = phys) do
    import Exiffer.Binary, only: [int32u_to_big_endian: 1]
    value = <<
      int32u_to_big_endian(phys.x_pixels_per_unit),
      int32u_to_big_endian(phys.y_pixels_per_unit),
      phys.unit
    >>
    Exiffer.Chunk.binary("pHYS", value)
  end

  def puts(%__MODULE__{} = phys) do
    unit = if phys.unit == 0, do: "Unknown", else: "meters"
    IO.puts """
    pHYs
    ----
    X-axis pixels per unit: #{phys.x_pixels_per_unit}
    Y-axis pixels per unit: #{phys.y_pixels_per_unit}
    Unit: #{unit}
    """
  end

  def write(phys, io_device) do
    binary = binary(phys)
    :ok = IO.binwrite(io_device, binary)
  end

  defimpl Exiffer.Serialize do
    alias Exiffer.Chunk.PHYS

    def binary(phys) do
      PHYS.binary(phys)
    end

    def puts(phys) do
      PHYS.puts(phys)
    end

    def write(phys, io_device) do
      PHYS.write(phys, io_device)
    end
  end
end
