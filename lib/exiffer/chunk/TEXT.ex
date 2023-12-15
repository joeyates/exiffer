defmodule Exiffer.Chunk.TEXT do
  defstruct ~w(keyword text)a
  def new(data) do
    [keyword, text] = String.split(data, <<0>>, parts: 2)
    %__MODULE__{keyword: keyword, text: text}
  end
end
