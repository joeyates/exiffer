defmodule Exiffer.PNG.Chunk.BKGD.RGB do
  defstruct ~w(r g b)a

  require Logger

  def binary(%__MODULE__{r: r, g: g, b: b}) do
    value = <<r, g, b>>
    Exiffer.PNG.Chunk.binary("BKGD", value)
  end

  def puts(%__MODULE__{r: r, g: g, b: b}) do
    """
    BKGD
    ----
    red: #{r}
    green: #{g}
    blue: #{b}
    """
  end

  def write(%__MODULE__{} = rgb, io_device) do
    Logger.debug "Writing BKGD.RGD chunk"
    binary = binary(rgb)
    :ok = IO.binwrite(io_device, binary)
  end

  defimpl Exiffer.Serialize do
    alias Exiffer.PNG.Chunk.BKGD.RGB

    def binary(rgb) do
      RGB.binary(rgb)
    end

    def puts(rgb) do
      RGB.puts(rgb)
    end

    def write(rgb, io_device) do
      RGB.write(rgb, io_device)
    end
  end
end
