defmodule Exiffer.Debug do
  @moduledoc """
  Documentation for `Exiffer.Debug`.
  """

  @doc """
  Dump binary bytes as hex.
  """
  def dump(message, binary, count \\ 20) do
    bytes = if String.length(binary) <= count do
      binary
    else
      <<head::binary-size(count), _rest::binary>> = binary
      head
    end
    IO.puts "#{message}: #{inspect(bytes, [pretty: true, width: 0, base: :hex])}"
  end
end
