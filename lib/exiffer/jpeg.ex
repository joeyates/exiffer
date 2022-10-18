defmodule Exiffer.JPEG do
  @moduledoc """
  Documentation for `Exiffer.JPEG`.
  """

  @doc """
  Parse JPEG headers.
  """
  def headers(data, headers)

  def headers(<<0xff, 0xc0, _unknown, length, rest::binary>>, headers) do
    binary_length = length - 3
    <<body::binary-size(binary_length), rest2::binary>> = rest
    {rest3, data} = Exiffer.Binary.consume_until(0xff, rest2, "")
    header = %{type: "JPEG SOF0", body: body, data: data}
    {rest4, headers} = headers(rest3, headers)
    {rest4, [header | headers]}
  end

  def headers(<<0xff, 0xc4, _unknown, length, rest::binary>>, headers) do
    dht_length = length - 3
    <<dht::binary-size(dht_length), rest2::binary>> = rest
    {rest3, data} = Exiffer.Binary.consume_until(0xff, rest2, "")
    header = %{type: "JPEG DHT", dht: dht, data: data}
    {rest4, headers} = headers(rest3, headers)
    {rest4, [header | headers]}
  end

  def headers(<<0xff, 0xda, _unknown, length, rest::binary>>, headers) do
    binary_length = length - 3
    <<body::binary-size(binary_length), rest2::binary>> = rest
    {rest3, data} = Exiffer.Binary.consume_until(0xff, rest2, "")
    header = %{type: "JPEG SOS", body: body, data: data}
    {rest3, [header | headers]}
  end

  def headers(<<0xff, 0xdb, _unknown, length, rest::binary>>, headers) do
    dqt_length = length - 3
    <<dqt::binary-size(dqt_length), rest2::binary>> = rest
    {rest3, data} = Exiffer.Binary.consume_until(0xff, rest2, "")
    header = %{type: "JPEG DQT", dqt: dqt, data: data}
    {rest4, headers} = headers(rest3, headers)
    {rest4, [header | headers]}
  end

  def headers(
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
      length: Exiffer.Binary.little_endian_to_decimal(length),
      version: version,
      density_units: density_units,
      x_density: Exiffer.Binary.little_endian_to_decimal(x_density),
      y_density: Exiffer.Binary.little_endian_to_decimal(y_density),
      x_thumbnail: x_thumbnail,
      y_thumbnail: y_thumbnail,
      thumbnail: thumbnail
    }
    {rest3, headers} = headers(rest2, headers)
    {rest3, [header | headers]}
  end

  def headers(<<0xff, 0xfe, _unknown, length, rest::binary>>, headers) do
    comment_length = length - 3
    <<comment::binary-size(comment_length), 0x00, rest2::binary>> = rest
    header = %{type: "JPEG COM Comment", comment: comment}
    {rest3, headers} = headers(rest2, headers)
    {rest3, [header | headers]}
  end

  def headers(rest, headers) do
    {rest, headers}
  end
end
