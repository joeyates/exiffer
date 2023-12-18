defmodule Exiffer.Binary do
  @moduledoc """
  Documentation for `Exiffer.Binary`.
  """

  import Bitwise
  require Logger

  @table :exiffer

  @spec optionally_create_ets_table() :: :ok
  def optionally_create_ets_table() do
    ref = :ets.whereis(@table)
    if ref == :undefined do
      Logger.debug "Initializing ETS table #{@table}"
      _name = :ets.new(@table, [:set, :public, :named_table])
    end
    :ok
  end

  @spec set_byte_order(:big | :little) :: true
  def set_byte_order(byte_order) do
    optionally_create_ets_table()
    :ets.insert(@table, {:byte_order, byte_order})
  end

  @spec byte_order() :: :big | :little
  def byte_order() do
    [byte_order: byte_order] = :ets.lookup(@table, :byte_order)
    byte_order
  end

  @spec to_integer(binary) :: non_neg_integer()
  @doc """
  Convert binary bytes to decimal based on endianness.
  """
  def to_integer(binary) do
    case byte_order() do
      :little -> little_endian_to_integer(binary)
      :big -> big_endian_to_integer(binary)
    end
  end

  @spec big_endian(binary) :: binary
  @doc """
  Force big endian byte order
  """
  def big_endian(binary) do
    case byte_order() do
      :little ->
        reverse(binary)
      :big ->
        binary
    end
  end

  @spec big_endian_to_current(binary) :: binary
  @doc """
  Convert big endian to the currently selected byte order
  """
  def big_endian_to_current(binary) do
    case byte_order() do
      :little ->
        reverse(binary)
      :big ->
        binary
    end
  end

  @spec int16u_to_current(integer) :: <<_::16>>
  @doc """
  Convert a 16-bit integer to binary bytes in current byte order.
  """
  def int16u_to_current(integer) do
    case byte_order() do
      :little ->
        int16u_to_little_endian(integer)
      :big ->
        int16u_to_big_endian(integer)
    end
  end

  @spec int32u_to_current(integer) :: <<_::32>>
  @doc """
  Convert a 32-bit integer to binary bytes in current byte order.
  """
  def int32u_to_current(integer) do
    case byte_order() do
      :little ->
        int32u_to_little_endian(integer)
      :big ->
        int32u_to_big_endian(integer)
    end
  end

  @spec reverse(binary) :: binary
  @doc """
  Reverse the given binary bytes
  """
  def reverse(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.reverse()
    |> :binary.list_to_bin()
  end

  @spec big_endian_to_integer(binary) :: non_neg_integer()
  @doc """
  Convert big-endian binary bytes to an integer.
  """
  def big_endian_to_integer(<<hi, lo>>) do
    256 * hi + lo
  end

  def big_endian_to_integer(<<b0, b1, b2, b3>>) do
    0x1000000 * b0 + 0x10000 * b1 + 0x100 * b2 + b3
  end

  @spec little_endian_to_integer(binary) :: non_neg_integer()
  @doc """
  Convert little-endian binary bytes to integer.
  """
  def little_endian_to_integer(<<lo, hi>>) do
    lo + 256 * hi
  end

  def little_endian_to_integer(<<b0, b1, b2, b3>>) do
    b0 + 0x100 * b1 + 0x10000 * b2 + 0x1000000 * b3
  end

  @spec int16u_to_big_endian(integer) :: <<_::16>>
  @doc """
  Convert a 16-bit integer to big-endian binary bytes.
  """
  def int16u_to_big_endian(integer) do
    <<
    (integer &&& 0xff00) >>> 8,
    (integer &&& 0x00ff)
    >>
  end

  @spec int16u_to_little_endian(integer) :: <<_::16>>
  @doc """
  Convert a 16-bit integer to little-endian binary bytes.
  """
  def int16u_to_little_endian(integer) do
    <<
    (integer &&& 0x00ff),
    (integer &&& 0xff00) >>> 8
    >>
  end

  @spec int32u_to_big_endian(integer) :: <<_::32>>
  @doc """
  Convert a 32-bit integer to big-endian binary bytes.
  """
  def int32u_to_big_endian(integer) do
    <<
    (integer &&& 0xff000000) >>> 24,
    (integer &&& 0x00ff0000) >>> 16,
    (integer &&& 0x0000ff00) >>> 8,
    (integer &&& 0x000000ff)
    >>
  end

  @spec int32u_to_little_endian(integer) :: <<_::32>>
  @doc """
  Convert a 32-bit integer to little-endian binary bytes.
  """
  def int32u_to_little_endian(integer) do
    <<
    (integer &&& 0x000000ff),
    (integer &&& 0x0000ff00) >>> 8,
    (integer &&& 0x00ff0000) >>> 16,
    (integer &&& 0xff000000) >>> 24
    >>
  end

  def rational_to_current(rationals) when is_list(rationals) do
    rationals
    |> Enum.map(&rational_to_current/1)
    |> Enum.join()
  end

  def rational_to_current({numerator, denominator}) do
    <<int32u_to_current(numerator)::binary, int32u_to_current(denominator)::binary>>
  end

  def signed_rational_to_current(rationals) when is_list(rationals) do
    rationals
    |> Enum.map(&signed_rational_to_current/1)
    |> Enum.join()
  end

  def signed_rational_to_current({numerator, denominator}) do
    # TODO: handle signed values
    <<int32u_to_current(numerator)::binary, int32u_to_current(denominator)::binary>>
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
