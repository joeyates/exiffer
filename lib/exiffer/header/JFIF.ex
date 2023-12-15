defmodule Exiffer.Header.JFIF do
  @moduledoc """
  Documentation for `Exiffer.Header.JFIF`.

  JFIF is the "JPEG File Interchange Format"
  """

  alias Exiffer.Binary
  alias Exiffer.IO.Buffer
  require Logger

  @enforce_keys ~w()a
  defstruct ~w(
    version
    resolution_units
    x_resolution
    y_resolution
    thumbnail_width
    thumbnail_height
    thumbnail
  )a

  defimpl Jason.Encoder  do
    @spec encode(%Exiffer.Header.JFIF{}, Jason.Encode.opts()) :: String.t()
    def encode(entry, opts) do
      Logger.debug("Encoding JFIF")
      Jason.Encode.map(
        %{
          module: "Exiffer.Header.JFIF",
          version: entry.version,
          resolution_units: entry.resolution_units,
          x_resolution: entry.x_resolution,
          y_resolution: entry.y_resolution,
          thumbnail_width: entry.thumbnail_width,
          thumbnail_height: entry.thumbnail_height,
          thumbnail: "(#{byte_size(entry.thumbnail)} bytes)",
        },
        opts
      )
    end
  end


  def new(
        %{data: <<0xFF, 0xE0, _length_binary::binary-size(2), "JFIF", 0x00, _rest::binary>>} =
          buffer
      ) do
    buffer = Buffer.skip(buffer, 9)
    {<<version::binary-size(2)>>, buffer} = Buffer.consume(buffer, 2)

    {<<resolution_units::binary-size(1), x_resolution::binary-size(2),
       y_resolution::binary-size(2)>>, buffer} = Buffer.consume(buffer, 5)

    {<<thumbnail_width, thumbnail_height>>, buffer} = Buffer.consume(buffer, 2)
    thumbnail_bytes = 3 * thumbnail_width * thumbnail_height
    {thumbnail, buffer} = Buffer.consume(buffer, thumbnail_bytes)

    jfif = %__MODULE__{
      version: version,
      resolution_units: resolution_units,
      x_resolution: Binary.to_integer(x_resolution),
      y_resolution: Binary.to_integer(y_resolution),
      thumbnail_width: thumbnail_width,
      thumbnail_height: thumbnail_height,
      thumbnail: thumbnail
    }

    {jfif, buffer}
  end

  def puts(%__MODULE__{} = jfif) do
    IO.puts("JPEG File Interchange Format")
    IO.puts("----------------------------")
    IO.puts("Version: #{version(jfif)}")
    IO.puts("Resolution units: #{jfif.resolution_units}")
    IO.puts("X Resolution: #{jfif.x_resolution}")
    IO.puts("Y Resolution: #{jfif.y_resolution}")
    IO.puts("Thumbnail width: #{jfif.thumbnail_width}")
    IO.puts("Thumbnail height: #{jfif.thumbnail_height}")
  end

  def version(jfif) do
    <<hi, lo>> = jfif.version
    "#{hi}.#{lo}"
  end

  def binary(%__MODULE__{} = jfif) do
    x_resolution = Binary.int16u_to_current(jfif.x_resolution)
    y_resolution = Binary.int16u_to_current(jfif.y_resolution)

    bytes = <<
      "JFIF"::binary,
      0x00,
      jfif.version::binary,
      jfif.resolution_units::binary,
      x_resolution::binary,
      y_resolution::binary,
      jfif.thumbnail_width,
      jfif.thumbnail_height,
      jfif.thumbnail::binary
    >>

    length = byte_size(bytes)
    length_binary = Binary.int16u_to_big_endian(2 + length)
    <<0xFF, 0xE0, length_binary::binary, bytes::binary>>
  end

  def write(jfif, io_device) do
    Logger.debug("Writing JFIF header")
    binary = binary(jfif)
    :ok = IO.binwrite(io_device, binary)
  end

  defimpl Exiffer.Serialize do
    def write(jfif, io_device) do
      Exiffer.Header.JFIF.write(jfif, io_device)
    end

    def binary(jfif) do
      Exiffer.Header.JFIF.binary(jfif)
    end

    def puts(jfif) do
      Exiffer.Header.JFIF.puts(jfif)
    end
  end
end
