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

  @jpeg_magic <<0xff, 0xd8>>

  def rewrite(source, destination) do
    input = Buffer.new(source)
    output = Buffer.new(destination, direction: :write)

    {headers, input} = parse(input)

    Buffer.write(output, @jpeg_magic)
    :ok = Exiffer.Serialize.write(headers, output.io_device)

    Buffer.copy(input, output)

    :ok = Buffer.close(input)
    :ok = Buffer.close(output)

    {:ok}
  end

  defp parse(filename) when is_binary(filename) do
    buffer = Buffer.new(filename)
    {headers, _buffer} = parse(buffer)
    :ok = Buffer.close(buffer)

    headers
  end

  defp parse(%Buffer{data: <<@jpeg_magic, _rest::binary>>} = buffer) do
    # TODO: Move this into JPEG.new
    buffer = Buffer.skip(buffer, 2)
    {buffer, headers} = JPEG.headers(buffer, [])
    headers = Enum.reverse(headers)
    {headers, buffer}
  end

  defp parse(%Buffer{}) do
    IO.puts "Unrecognized file format"
  end
end
