defmodule Exiffer.Binary do
  @moduledoc """
  Documentation for `Exiffer.Binary`.
  """

  @table :exiffer

  def optionally_create_ets_table() do
    if :ets.whereis(@table) do
      _name = :ets.new(@table, [:set, :public, :named_table])
    end
  end

  def set_byte_order(byte_order) do
    optionally_create_ets_table()
    :ets.insert(@table, {:byte_order, byte_order})
  end

  def byte_order() do
    [byte_order: byte_order] = :ets.lookup(@table, :byte_order)
    byte_order
  end

  @doc """
  Convert binary bytes to decimal based on endianness.
  """
  def to_integer(binary) do
    case byte_order() do
      :little -> little_endian_to_integer(binary)
      :big -> big_endian_to_integer(binary)
    end
  end

  @doc """
  Force big endian byte order
  """
  def big_endian(binary) do
    case byte_order() do
      :little ->
        binary
        |> :binary.bin_to_list()
        |> Enum.reverse()
        |> :binary.list_to_bin()
      :big ->
        binary
    end
  end

  @doc """
  Convert binary bytes to decimal.
  """
  def big_endian_to_integer(<<hi, lo>>) do
    256 * hi + lo
  end

  def big_endian_to_integer(<<b0, b1, b2, b3>>) do
    0x1000000 * b0 + 0x10000 * b1 + 0x100 * b2 + b3
  end

  @doc """
  Convert binary bytes to decimal.
  """
  def little_endian_to_integer(<<lo, hi>>) do
    lo + 256 * hi
  end

  def little_endian_to_integer(<<b0, b1, b2, b3>>) do
    b0 + 0x100 * b1 + 0x10000 * b2 + 0x1000000 * b3
  end

  # TODO: handle negatives
  def to_signed(<<b0, b1, b2, b3>>) do
    b0 + 0x100 * b1 + 0x10000 * b2 + 0x1000000 * b3
  end

  @doc """
  When given 8 bytes, returns a single {numerator, denominator} tuple.
  When given multiples of 8 bytes, returns a list of those tuples.
  """
  def to_rational(<<numerator::binary-size(4), denominator::binary-size(4)>>) do
    {to_integer(numerator), to_integer(denominator)}
  end

  def to_rational(<<rational1::binary-size(8), rational2::binary-size(8)>>) do
    [to_rational(rational1), to_rational(rational2)]
  end

  def to_rational(<<rational::binary-size(8), rest::binary>>) do
    [to_rational(rational) | to_rational(rest)]
  end

  @doc """
  When given 8 bytes, returns a single {numerator, denominator} tuple.
  When given multiples of 8 bytes, returns a list of those tuples.
  """
  def to_signed_rational(<<numerator::binary-size(4), denominator::binary-size(4)>>) do
    # TODO: handle signed
    {to_integer(numerator), to_integer(denominator)}
  end

  def to_signed_rational(<<rational1::binary-size(8), rational2::binary-size(8)>>) do
    [to_signed_rational(rational1), to_signed_rational(rational2)]
  end

  def to_signed_rational(<<rational::binary-size(8), rest::binary>>) do
    [to_signed_rational(rational) | to_signed_rational(rest)]
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
