defmodule Exiffer.PNG.Chunk.TIME do
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

  def binary(time) do
    value = <<
      Binary.int16u_to_big_endian(time.year),
      time.month,
      time.day,
      time.hour,
      time.minute,
      time.second
    >>
    Exiffer.PNG.Chunk.binary("tIME", value)
  end

  def puts(time) do
    IO.puts """
    tIME
    ----
    Year: #{time.year}
    Month: #{time.month}
    Day: #{time.day}
    Hour: #{time.hour}
    Minute: #{time.minute}
    Second: #{time.second}
    """
  end

  def write(time, io_device) do
    binary = binary(time)
    :ok = IO.binwrite(io_device, binary)
  end

  defimpl Exiffer.Serialize do
    alias Exiffer.PNG.Chunk.TIME

    def binary(time) do
      TIME.binary(time)
    end

    def puts(time) do
      TIME.puts(time)
    end

    def write(time, io_device) do
      TIME.write(time, io_device)
    end
  end
end
