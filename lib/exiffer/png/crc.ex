defmodule Exiffer.PNG.CRC do
  @moduledoc """
  Documentation for `Exiffer.PNG.CRC`.

  Calculate CRC32
  """

  import Bitwise

  @doc """
  Code from http://www.libpng.org/pub/png/spec/1.2/PNG-CRCAppendix.html

  This code generates a lookup table used to compute the CRC values for
  PNG chunks. See the PNG specification for further details.
  """

  @crc_table Enum.map(
               0..255,
               fn n ->
                 Enum.reduce(
                   0..7,
                   n,
                   fn _k, c ->
                     shifted = c >>> 1

                     if (c &&& 1) == 1 do
                       bxor(0xEDB88320, shifted)
                     else
                       shifted
                     end
                   end
                 )
               end
             )

  def crc(blob) when is_binary(blob) do
    0xFFFFFFFF
    |> update(0, blob)
    |> bxor(0xFFFFFFFF)
    |> then(fn n ->
      <<n >>> 24, n >>> 16 &&& 0xFF, n >>> 8 &&& 0xFF, n &&& 0xFF>>
    end)
  end

  defp update(crc, _n, ""), do: crc

  defp update(crc, n, <<byte>> <> rest) do
    index = bxor(crc, byte) &&& 0xFF
    item = Enum.at(@crc_table, index)
    crc = bxor(item, crc >>> 8)
    update(crc, n + 1, rest)
  end
end
