defmodule Exiffer.Rewrite do
  @moduledoc """
  Rewrite an image file, adding and removing arbitrary metadata
  """

  alias Exiffer.{Binary, GPS, JPEG}
  alias Exiffer.IO.Buffer

  require Logger

  def rewrite(source, destination, rewrite_fun) when is_function(rewrite_fun, 1) do
    source_stat = File.stat!(source)
    input = Buffer.new(source)
    {jpeg, input} = Exiffer.parse(input)

    %JPEG{} = updated = rewrite_fun.(jpeg)

    Binary.set_byte_order(:big)
    output = Buffer.new(destination, direction: :write)

    :ok = Exiffer.Serialize.write(updated, output.io_device)
    :ok = Buffer.close(input)
    :ok = Buffer.close(output)
    File.write_stat!(destination, source_stat)

    :ok
  end

  def set_make_and_model(source, destination, make, model) do
    Logger.info("Exiffer.Rewrite.set_make_and_model/4")

    rewrite(source, destination, fn jpeg ->
      jpeg
      |> JPEG.set_field(:make, make)
      |> JPEG.set_field(:model, model)
    end)
  end

  def set_date_time(source, destination, %DateTime{} = date_time) do
    set_date_time(source, destination, DateTime.to_naive(date_time))
  end

  def set_date_time(source, destination, %NaiveDateTime{} = date_time) do
    Logger.info("Exiffer.Rewrite.set_date_time/3")
    rewrite(source, destination, &JPEG.set_date_time(&1, date_time))
  end

  def set_gps(source, destination, %GPS{} = gps) do
    Logger.info("Exiffer.Rewrite.set_gps/3")

    rewrite(source, destination, &JPEG.set_gps(&1, gps))
  end
end
