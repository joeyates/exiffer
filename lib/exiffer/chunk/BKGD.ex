defmodule Exiffer.Chunk.BKGD do
  alias Exiffer.Chunk.BKGD.{PaletteIndex, Gray, RGB}

  def new(<<data::binary-size(1)>>) do
    %PaletteIndex{index: data}
  end

  def new(<<data::binary-size(2)>>) do
    %Gray{gray: data}
  end

  def new(<<r::binary-size(2), g::binary-size(2), b::binary-size(2)>>) do
    %RGB{r: r, g: g, b: b}
  end
end
