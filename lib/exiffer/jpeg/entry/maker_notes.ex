defmodule Exiffer.JPEG.Entry.MakerNotes do
  @moduledoc """
  Documentation for `Exiffer.JPEG.Entry.MakerNotes`.
  """

  @enforce_keys ~w(ifd)a
  defstruct ~w(ifd)a

  defimpl Jason.Encoder  do
    @spec encode(%Exiffer.JPEG.Entry.MakerNotes{}, Jason.Encode.opts()) :: String.t()
    def encode(entry, opts) do
      Jason.Encode.map(
        %{
          module: "Exiffer.Entry.MakerNotes",
          ifd: entry.ifd
        },
        opts
      )
    end
  end
end
