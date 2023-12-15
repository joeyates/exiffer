defmodule Exiffer.Chunk.TIME do
  defstruct ~w(year month day hour minute second)a

  alias Exiffer.Binary

  def new(<<
        year_binary::binary-size(2),
        month,
        day,
        hour,
        minute,
        second
      >>) do
    year = Binary.to_integer(year_binary)
    %__MODULE__{year: year, month: month, day: day, hour: hour, minute: minute, second: second}
  end
end
