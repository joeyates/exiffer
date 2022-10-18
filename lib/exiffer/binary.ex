defmodule Exiffer.Binary do
  @moduledoc """
  Documentation for `Exiffer.Binary`.
  """

  @doc """
  Convert binary bytes to decimal.
  """
  def little_endian_to_decimal(<<lo, hi>>) do
    lo + 256 * hi
  end

  @doc """
  Read bytes from binary data up until, but excluding, a specific byte value.
  """
  def consume_until(match, <<match, _rest::binary>> = binary, consumed) do
    {binary, consumed}
  end

  def consume_until(match, <<byte, rest::binary>>, consumed) do
    consume_until(match, rest, <<consumed::binary, byte>>)
  end
end
