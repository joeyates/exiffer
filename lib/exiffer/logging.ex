defmodule Exiffer.Logging do
  @moduledoc """
  Documentation for `Exiffer.Logging`.
  """

  def integer(integer) do
    "0x#{Integer.to_string(integer, 16)} (#{integer})"
  end

  def pair(<<a, b>>) do
    "<<0x#{Integer.to_string(a, 16)}, 0x#{Integer.to_string(b, 16)}>>"
  end
end
