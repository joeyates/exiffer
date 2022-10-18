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
    {:ok, io_device} = File.open(filename)
    head = IO.binread(io_device, 2048)
    exif = parse(io_device, head)
    File.close(io_device)

    IO.puts "exif: #{inspect(exif, [pretty: true, width: 0])}"

    {:ok}
  end

  defp parse(_io_device, <<0xff, 0xd8>> <> body) do
    {_rest, headers} = Exiffer.JPEG.headers(body, [])
    headers
  end

  defp parse(_io_device, _data) do
    IO.puts "Unrecognized file format"
  end
end
