defmodule Exiffer.JPEG.Entry.Info do
  @moduledoc """
  Defines a struct holding information for JPEG entries including alternative known data types.
  """

  @keys ~w(type magic formats label)a
  @enforce_keys @keys
  defstruct @keys
end
