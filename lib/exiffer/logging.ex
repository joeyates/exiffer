defmodule Exiffer.Logging do
  @moduledoc """
  Documentation for `Exiffer.Logging`.
  """

  def integer(integer) do
    "0x#{Integer.to_string(integer, 16)} (#{integer})"
  end
end
