defmodule Exiffer.Header.JFIF do
  @moduledoc """
  Documentation for `Exiffer.Header.JFIF`.

  JFIF is the "JPEG File Interchange Format"
  """

  alias Exiffer.Binary
  alias Exiffer.Buffer
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

  def new(%Buffer{data: <<0xff, 0xe0, _rest::binary>>} = buffer) do
    buffer = Buffer.skip(buffer, 2)
    {<<_length_binary::binary-size(2), "JFIF", 0x00>>, buffer} = Buffer.consume(buffer, 7)
    {<<version::binary-size(2)>>, buffer} = Buffer.consume(buffer, 2)
    {<<resolution_units::binary-size(1), x_resolution::binary-size(2), y_resolution::binary-size(2)>>, buffer} = Buffer.consume(buffer, 5)
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
    IO.puts "JPEG File Interchange Format"
    IO.puts "----------------------------"
    IO.puts "Version: #{version(jfif)}"
    IO.puts "Resolution units: #{jfif.resolution_units}"
    IO.puts "X Resolution: #{jfif.x_resolution}"
    IO.puts "Y Resolution: #{jfif.y_resolution}"
    IO.puts "Thumbnail width: #{jfif.thumbnail_width}"
    IO.puts "Thumbnail height: #{jfif.thumbnail_height}"
  end

  def version(jfif) do
    <<hi, lo>> = jfif.version
    "#{hi}.#{lo}"
  end

  defimpl Exiffer.Serialize do
    def write(_jfif, _io_device) do
    end

    def binary(_jfif) do
      <<>>
    end

    def puts(jfif) do
      Exiffer.Header.JFIF.puts(jfif)
    end
  end
end
