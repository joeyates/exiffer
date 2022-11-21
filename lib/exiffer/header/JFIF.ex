defmodule Exiffer.Header.JFIF do
  @moduledoc """
  Documentation for `Exiffer.Header.JFIF`.

  JFIF is the "JPEG File Interchange Format"
  """

  @enforce_keys ~w(type)a
  defstruct ~w(
    type
    version
    density_units
    x_density
    y_density
    x_thumbnail
    y_thumbnail
    thumbnail
  )a
end
