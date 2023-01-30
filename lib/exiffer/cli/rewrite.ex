defmodule Exiffer.CLI.Rewrite do
  @moduledoc """
  Documentation for `Exiffer.CLI.Rewrite`.
  """

  alias Exiffer.Buffer
  alias Exiffer.Entry
  alias Exiffer.Header.APP1.EXIF
  alias Exiffer.IFD
  alias Exiffer.IFDBlock
  require Logger

  @jpeg_magic <<0xff, 0xd8>>

  @doc """
  Rewrite an image's metadata.
  """
  def run(source, destination, gps, opts \\ []) do
    logger_level = Keyword.get(opts, :log_level, :error)
    level = Logger.level()
    Logger.configure(level: logger_level)

    input = Buffer.new(source)
    output = Buffer.new(destination, direction: :write)

    {metadata, input} = Exiffer.parse(input)

    entry = build_entry(gps)

    {:ok, headers} = apply_gps(headers, entry)

    Buffer.write(output, @jpeg_magic)
    :ok = Exiffer.Serialize.write(metadata, output.io_device)

    Buffer.copy(input, output)

    :ok = Buffer.close(input)
    :ok = Buffer.close(output)

    Logger.configure(level: level)

    {:ok}
  end

  def build_entry(gps) do
    {latitude, longitude, altitude} = parse_gps(gps)
    latitude_ref = if latitude >= 0, do: "N", else: "S"
    longitude_ref = if longitude >= 0, do: "W", else: "E"
    latitude = latitude |> float_to_dms() |> dms_to_rational()
    longitude = longitude |> float_to_dms() |> dms_to_rational()
    altitude = floor(altitude)

    value = %Exiffer.IFD{
      entries: [
        Exiffer.Entry.new_by_type(:gps_latitude_ref, latitude_ref),
        Exiffer.Entry.new_by_type(:gps_latitude, latitude),
        Exiffer.Entry.new_by_type(:gps_longitude_ref, longitude_ref),
        Exiffer.Entry.new_by_type(:gps_longitude, longitude),
        Exiffer.Entry.new_by_type(:gps_altitude_ref, 0),
        Exiffer.Entry.new_by_type(:gps_altitude, {altitude, 1})
      ]
    }
    Exiffer.Entry.new_by_type(:gps_info, value)
  end

  defp parse_gps(gps) do
    case Regex.named_captures(
      ~r/(?<latitude>\d{1,3}[.,]\d+),(?<longitude>\d{1,3}[.,]\d+),(?<altitude>\d+)/,
      gps
    ) do
      %{"latitude" => latitude, "longitude" => longitude, "altitude" => altitude} ->
        {to_f(latitude), to_f(longitude), to_f(altitude)}
      _ ->
        nil
    end
  end

  defp to_f(s) do
    s
    |> Float.parse()
    |> elem(0)
  end

  defp float_to_dms(f) do
    abs = abs(f)
    degrees = floor(abs)
    degrees_remainder = abs - degrees
    minutes = floor(60 * degrees_remainder)
    minutes_remainder = degrees_remainder - minutes / 60
    seconds = 3600 * minutes_remainder
    {degrees, minutes, seconds}
  end

  defp dms_to_rational({d, m, s}) do
    mus = floor(s * 1_000_000)
    [{d, 1}, {m, 1}, {mus, 1_000_000}]
  end

  defp apply_gps(headers, entry) do
    {:ok, headers} = remove_gps(headers)
    {:ok, _headers} = add_gps(headers, entry)
  end

  defp add_gps(headers, entry) when is_list(headers) do
    headers = Enum.map(headers, &(add_gps(&1, entry)))
    {:ok, headers}
  end

  defp add_gps(%EXIF{} = exif, entry) do
    ifd_block = add_gps(exif.ifd_block, entry)
    struct!(exif, ifd_block: ifd_block)
  end

  defp add_gps(%IFDBlock{} = ifd_block, entry) do
    [ifd | others] = ifd_block.ifds
    ifd = add_gps(ifd, entry)
    struct!(ifd_block, ifds: [ifd | others])
  end

  defp add_gps(%IFD{} = ifd, entry) do
    entries = Enum.reverse([entry | Enum.reverse(ifd.entries)])
    struct!(ifd, entries: entries)
  end

  defp add_gps(item, _entry), do: item

  defp remove_gps(headers) when is_list(headers) do
    headers = Enum.map(headers, &(remove_gps(&1)))
    {:ok, headers}
  end

  defp remove_gps(%EXIF{} = exif) do
    ifd_block = remove_gps(exif.ifd_block)
    struct!(exif, ifd_block: ifd_block)
  end

  defp remove_gps(%IFDBlock{} = ifd_block) do
    ifds = Enum.map(ifd_block.ifds, &(remove_gps(&1)))
    struct!(ifd_block, ifds: ifds)
  end

  defp remove_gps(%IFD{} = ifd) do
    entries =
      ifd.entries
      |> Enum.map(&(remove_gps(&1)))
      |> Enum.filter(&(&1))
    struct!(ifd, entries: entries)
  end

  defp remove_gps(%Entry{type: :gps_info}) do
    nil
  end

  defp remove_gps(item) do
    item
  end
end
