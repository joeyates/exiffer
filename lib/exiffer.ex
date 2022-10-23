defmodule Exiffer do
  @moduledoc """
  Documentation for `Exiffer`.
  """

  @doc """
  Dump image file metadata.

  ## Examples

      iex> Exiffer.dump(["example.jpg"])
      {:ok}

  """
  def dump([filename]) do
    buffer = Exiffer.Buffer.new(filename)
    exif = parse(buffer)
    :ok = Exiffer.Buffer.close(buffer)

    IO.puts "exif: #{inspect(exif, [pretty: true, width: 0])}"

    {:ok}
  end

  defp parse(%Exiffer.Buffer{data: <<0xff, 0xd8, _rest::binary>>} = buffer) do
    buffer = Exiffer.Buffer.skip(buffer, 2)
    {_buffer, headers} = Exiffer.JPEG.headers(buffer, [])
    Enum.reverse(headers)
  end

  defp parse(%Exiffer.Buffer{}) do
    IO.puts "Unrecognized file format"
  end
end
