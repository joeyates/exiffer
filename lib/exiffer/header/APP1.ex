defmodule Exiffer.Header.APP1 do
  @moduledoc """
  Documentation for `Exiffer.Header.APP1`.
  """

  defstruct ~w(
    byte_order
    ifds
    thumbnail
    exif_ifd
    gps_ifd
  )a
end
