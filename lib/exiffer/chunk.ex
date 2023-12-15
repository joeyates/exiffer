defmodule Exiffer.Chunk do
  @moduledoc """
  Documentation for `Exiffer.Chunk`.

  http://www.libpng.org/pub/png/spec/1.2/PNG-Chunks.html
  """

  require Logger

  alias Exiffer.Chunk.{BKGD, ICCP, IDAT, IEND, IHDR, PHYS, PLTE, TEXT, TIME, Unknown}

  def new(_length, "bKGD", data, _crc) do
    Logger.debug("Reading bKGD chunk")
    BKGD.new(data)
  end

  def new(_length, "iCCP", data, _crc) do
    Logger.debug("Reading ICCP chunk")
    ICCP.new(data)
  end

  def new(_length, "IDAT", data, _crc) do
    Logger.debug("Reading IDAT chunk")
    %IDAT{data: data}
  end

  def new(_length, "IEND", <<>>, _crc) do
    Logger.debug("Reading IEND chunk")
    %IEND{}
  end

  def new(_length, "IHDR", data, _crc) do
    Logger.debug("Reading IHDR chunk")
    IHDR.new(data)
  end

  def new(_length, "pHYs", data, _crc) do
    Logger.debug("Reading pHYs chunk")
    PHYS.new(data)
  end

  def new(_length, "PLTE", data, _crc) do
    Logger.debug("Reading PLTE chunk")
    PLTE.new(data)
  end

  def new(_length, "tEXt", data, _crc) do
    Logger.debug("Reading tEXt chunk")
    TEXT.new(data)
  end

  def new(_length, "tIME", data, _crc) do
    Logger.debug("Reading tIME chunk")
    TIME.new(data)
  end

  def new(length, type, data, crc) do
    Logger.debug("Reading unknown chunk")
    %Unknown{length: length, type: type, data: data, crc: crc}
  end
end
