defmodule Exiffer.Chunk.TEXT do
  defstruct ~w(keyword text)a

  def new(data) do
    [keyword, text] = String.split(data, <<0>>, parts: 2)
    %__MODULE__{keyword: keyword, text: text}
  end

  def binary(%__MODULE__{} = text) do
    value = <<
      text.keyword,
      0,
      text.text
    >>
    Exiffer.Chunk.binary("tEXt", value)
  end

  def puts(%__MODULE__{} = text) do
    IO.puts """
    tEXt
    ----
    Keyword: #{text.keyword}
    Text: #{text.text}
    """
  end

  def write(item, io_device) do
    binary = binary(item)
    :ok = IO.binwrite(io_device, binary)
  end

  defimpl Exiffer.Serialize do
    alias Exiffer.Chunk.TEXT

    def binary(text) do
      TEXT.binary(text)
    end

    def puts(text) do
      TEXT.puts(text)
    end

    def write(text, io_device) do
      TEXT.write(text, io_device)
    end
  end
end
