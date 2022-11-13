defmodule Exiffer do
  @moduledoc """
  Documentation for `Exiffer`.
  """

  alias Exiffer.Buffer
  alias Exiffer.JPEG

  @doc """
  Dump image file metadata.

  ## Examples

      iex> Exiffer.dump(["example.jpg"])
      {:ok}

  """
  def dump(filename) do
    buffer = Buffer.new(filename)
    exif = parse(buffer)
    :ok = Buffer.close(buffer)

    IO.puts "exif: #{inspect(exif, [pretty: true, width: 0])}"

    {:ok}
  end

  defp parse(%Buffer{data: <<0xff, 0xd8, _rest::binary>>} = buffer) do
    buffer = Buffer.skip(buffer, 2)
    {_buffer, headers} = JPEG.headers(buffer, [])
    Enum.reverse(headers)
  end

  defp parse(%Buffer{}) do
    IO.puts "Unrecognized file format"
  end
end
