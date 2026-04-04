defmodule Exiffer.Binary.Rewrite do
  @moduledoc """
  Rewrite an image file in memory
  """

  alias Exiffer.GPS
  alias Exiffer.JPEG

  def rewrite(source, rewrite_fun) when is_function(rewrite_fun, 1) do
    header_binary =
      source
      |> Exiffer.parse_binary()
      |> rewrite_fun.()
      |> Exiffer.Serialize.binary()

    <<JPEG.magic()::binary, header_binary::binary>>
  end

  def set_make_and_model(source, make, model) do
    rewrite(source, fn jpeg ->
      jpeg
      |> JPEG.set_exif_field(:make, make)
      |> JPEG.set_exif_field(:model, model)
    end)
  end

  def set_date_time(source, %NaiveDateTime{} = date_time) do
    rewrite(source, fn jpeg ->
      jpeg
      |> JPEG.set_modification_date(date_time)
      |> JPEG.set_date_time_original(date_time)
      |> JPEG.set_create_date(date_time)
    end)
  end

  def set_gps(source, %GPS{} = gps) do
    rewrite(source, &JPEG.set_gps(&1, gps))
  end

  def set_field(source, field, value) do
    rewrite(source, &JPEG.set_exif_field(&1, field, value))
  end
end
