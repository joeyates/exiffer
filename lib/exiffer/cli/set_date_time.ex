defmodule Exiffer.CLI.SetDateTime do
  @moduledoc """
  Documentation for `Exiffer.CLI.SetDateTime`.
  """

  require Logger

  alias Exiffer.Rewrite

  @spec run(map) :: {:ok}
  @doc """
  Rewrite an image's creation metadata.
  """
  def run(opts) do
    Logger.info "Exiffer.CLI.SetDateTime.run/4"
    source = Map.fetch!(opts, :source)
    destination = Map.fetch!(opts, :destination)
    year = Map.fetch!(opts, :year)
    month = Map.get(opts, :month, 1)
    day = Map.get(opts, :day, 1)
    hour = Map.get(opts, :hour, 0)
    minute = Map.get(opts, :minute, 0)
    second = Map.get(opts, :second, 0)

    date_time = NaiveDateTime.new!(year, month, day, hour, minute, second)

    {:ok} = Rewrite.set_date_time(source, destination, date_time)
  end
end
