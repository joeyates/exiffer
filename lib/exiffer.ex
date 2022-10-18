defmodule Exiffer do
  @moduledoc """
  Documentation for `Exiffer`.
  """

  @doc """
  Dump image file metadata.

  ## Examples

      iex> Exiffer.run(["example.jpg"])
      {:ok}

  """
  def run([filename]) do
    {:ok, io_device} = File.open(filename)
    head = IO.binread(io_device, 2048)
    exif = parse(io_device, head)
    File.close(io_device)

    IO.puts "exif: #{inspect(exif, [pretty: true, width: 0])}"

    {:ok}
  end

  defp parse(_io_device, <<0xff, 0xd8>> <> body) do
    {_rest, headers} = jpeg_headers(body, [])
    headers
  end

  defp parse(_io_device, _data) do
    IO.puts "Unrecognized file format"
  end

  defp jpeg_headers(<<0xff, 0xc0, _unknown, length, rest::binary>>, headers) do
    binary_length = length - 3
    <<body::binary-size(binary_length), rest2::binary>> = rest
    {rest3, data} = consume_until(0xff, rest2, "")
    header = %{type: "JPEG SOF0", body: body, data: data}
    {rest4, headers} = jpeg_headers(rest3, headers)
    {rest4, [header | headers]}
  end

  defp jpeg_headers(<<0xff, 0xc4, _unknown, length, rest::binary>>, headers) do
    dht_length = length - 3
    <<dht::binary-size(dht_length), rest2::binary>> = rest
    {rest3, data} = consume_until(0xff, rest2, "")
    header = %{type: "JPEG DHT", dht: dht, data: data}
    {rest4, headers} = jpeg_headers(rest3, headers)
    {rest4, [header | headers]}
  end

  defp jpeg_headers(<<0xff, 0xda, _unknown, length, rest::binary>>, headers) do
    binary_length = length - 3
    <<body::binary-size(binary_length), rest2::binary>> = rest
    {rest3, data} = consume_until(0xff, rest2, "")
    header = %{type: "JPEG SOS", body: body, data: data}
    {rest3, [header | headers]}
  end

  defp jpeg_headers(<<0xff, 0xdb, _unknown, length, rest::binary>>, headers) do
    dqt_length = length - 3
    <<dqt::binary-size(dqt_length), rest2::binary>> = rest
    {rest3, data} = consume_until(0xff, rest2, "")
    header = %{type: "JPEG DQT", dqt: dqt, data: data}
    {rest4, headers} = jpeg_headers(rest3, headers)
    {rest4, [header | headers]}
  end

  defp jpeg_headers(
    <<
    0xff,
    0xe0,
    length::binary-size(2),
    "JFIF",
    version::binary-size(2),
    density_units,
    x_density::binary-size(2),
    y_density::binary-size(2),
    x_thumbnail,
    y_thumbnail,
    0x00,
    rest::binary
    >>,
    headers
  ) do
    thumbnail_bytes = 3 * x_thumbnail * y_thumbnail
    <<thumbnail::binary-size(thumbnail_bytes), rest2::binary>> = rest
    header = %{
      type: "JFIF APP0",
      length: binary_little_endian_to_decimal(length),
      version: version,
      density_units: density_units,
      x_density: binary_little_endian_to_decimal(x_density),
      y_density: binary_little_endian_to_decimal(y_density),
      x_thumbnail: x_thumbnail,
      y_thumbnail: y_thumbnail,
      thumbnail: thumbnail
    }
    {rest3, headers} = jpeg_headers(rest2, headers)
    {rest3, [header | headers]}
  end

  defp jpeg_headers(<<0xff, 0xfe, _unknown, length, rest::binary>>, headers) do
    comment_length = length - 3
    <<comment::binary-size(comment_length), 0x00, rest2::binary>> = rest
    header = %{type: "JPEG COM Comment", comment: comment}
    {rest3, headers} = jpeg_headers(rest2, headers)
    {rest3, [header | headers]}
  end

  defp jpeg_headers(rest, headers) do
    {rest, headers}
  end

  def binary_little_endian_to_decimal(<<lo, hi>>) do
    lo + 256 * hi
  end

  def consume_until(match, <<match, _rest::binary>> = binary, consumed) do
    {binary, consumed}
  end

  def consume_until(match, <<byte, rest::binary>>, consumed) do
    consume_until(match, rest, <<consumed::binary, byte>>)
  end
end
