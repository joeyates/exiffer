defmodule Exiffer.PNG.Chunk.PLTE do
  defstruct ~w(colors)a

  require Logger

  alias Exiffer.PNG.Chunk.PLTE.Color

  @doc ~S"""
  Parse an PLTE PNG.chunk.

      iex> Exiffer.PNG.Chunk.PLTE.new(<<1, 2, 3>>)
      %Exiffer.PNG.Chunk.PLTE{colors: [%Exiffer.PNG.Chunk.PLTE.Color{r: 1, g: 2, b: 3}]}
  """
  def new(data) do
    Logger.debug("Parsing PLTE")
    colors =
      data
      |> stream()
      |> Enum.map(fn {r, g, b} -> %Color{r: r, g: g, b: b} end)
    %__MODULE__{colors: colors}
  end

  defp stream(data) do
    Stream.resource(
      fn -> data end,
      fn
        <<>> ->
          {:halt, nil}
        <<r, g, b, rest::binary>> ->
          {[{r, g, b}], rest}
      end,
      fn _ -> :done end
    )
  end
end
