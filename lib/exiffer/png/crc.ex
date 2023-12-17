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

  @crc_table 0..255
    |> Enum.map(fn n ->
      0..7
      |> Enum.reduce(
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
    end)

  def crc(blob) when is_binary(blob) do
    update(0xffffffff, 0, blob)
    |> bxor(0xffffffff)
    |> then(fn n ->
      <<n >>> 24, n >>> 16 &&& 0xff, n >>> 8 &&& 0xff, n &&& 0xff>>
    end)
  end

  defp update(crc, _n, <<>>), do: crc

  defp update(crc, n, <<byte, rest::binary>>) do
    index = (bxor(crc, byte) &&& 0xff)
    item = Enum.at(@crc_table, index)
    crc = bxor(item, crc >>> 8)
    update(crc, n + 1, rest)
  end
end
