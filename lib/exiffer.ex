defmodule Exiffer do
  @moduledoc """
  Documentation for `Exiffer`.
  """

  alias Exiffer.Buffer
  alias Exiffer.JPEG
  require Logger

  @doc """
  Dump image file metadata.

  ## Examples

      iex> Exiffer.dump(["example.jpg"])
      {:ok}

  """
  def dump(filename) do
    Logger.info "Exiffer.dump: '#{filename}'"
    headers = parse(filename)

    IO.puts "headers: #{inspect(headers, [pretty: true, width: 0])}"

    {:ok}
  end

  defp parse(filename) when is_binary(filename) do
    buffer = Buffer.new(filename)
    {headers, _buffer} = parse(buffer)
    :ok = Buffer.close(buffer)

    headers
  end

  defp parse(%Buffer{data: <<0xff, 0xd8, _rest::binary>>} = buffer) do
    buffer = Buffer.skip(buffer, 2)
    {_buffer, headers} = JPEG.headers(buffer, [])
    headers = Enum.reverse(headers)
    {headers, buffer}
  end

  defp parse(%Buffer{}) do
    IO.puts "Unrecognized file format"
  end
end
