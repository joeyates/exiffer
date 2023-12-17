defmodule Exiffer.PNG.Chunk do
  @moduledoc """
  Documentation for `Exiffer.PNG.Chunk`.

  http://www.libpng.org/pub/png/spec/1.2/PNG-Chunks.html
  """

  require Logger

  alias Exiffer.PNG.Chunk.{BKGD, ICCP, IDAT, IEND, IHDR, PHYS, PLTE, TEXT, TIME, Unknown}

  def new("bKGD", data) do
    Logger.debug("Reading bKGD chunk")
    BKGD.new(data)
  end

  def new("iCCP", data) do
    Logger.debug("Reading ICCP chunk")
    ICCP.new(data)
  end

  def new("IDAT", data) do
    Logger.debug("Reading IDAT chunk")
    %IDAT{data: data}
  end

  def new("IEND", <<>>) do
    Logger.debug("Reading IEND chunk")
    %IEND{}
  end

  def new("IHDR", data) do
    Logger.debug("Reading IHDR chunk")
    IHDR.new(data)
  end

  def new("pHYs", data) do
    Logger.debug("Reading pHYs chunk")
    PHYS.new(data)
  end

  def new("PLTE", data) do
    Logger.debug("Reading PLTE chunk")
    PLTE.new(data)
  end

  def new("tEXt", data) do
    Logger.debug("Reading tEXt chunk")
    TEXT.new(data)
  end

  def new("tIME", data) do
    Logger.debug("Reading tIME chunk")
    TIME.new(data)
  end

  def new(type, data) do
    Logger.debug("Reading unknown chunk")
    %Unknown{type: type, data: data}
  end

  def binary(type, value) do
    alias Exiffer.PNG.CRC

    length = byte_size(value)
    length_binary = Exiffer.Binary.int32u_to_big_endian(length)
    crc_binary = CRC.crc(<<type::binary, value::binary>>)
    <<length_binary::binary, type::binary, value::binary, crc_binary::binary>>
  end
end
