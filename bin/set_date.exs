#!/usr/bin/env elixir

Mix.install(
  [{:exiffer, "~> 0.2.0", path: "."}],
  verbose: true
)

require Logger

alias Exiffer.Rewrite

Logger.configure(level: :none)

argv = System.argv()

if length(argv) != 1 do
  IO.puts("Usage: set_date.exs <path>")
  System.halt(1)
end

defmodule DateSetter do
  @modification_date_match ~r"Modification Date:\s+(?<year>\d{4})[-:](?<month>\d{2})[-:](?<day>\d{2}) (?<hour>\d{2}):(?<minute>\d{2}):(?<second>\d{2})"

  def modification_date(filename) do
    metadata = Exiffer.parse(filename)
    text = Exiffer.Serialize.text(metadata)

    case Regex.named_captures(@modification_date_match, text) do
      nil ->
        {:error, nil}

      match ->
        {
          :ok,
          NaiveDateTime.new!(
            String.to_integer(match["year"]),
            String.to_integer(match["month"]),
            String.to_integer(match["day"]),
            String.to_integer(match["hour"]),
            String.to_integer(match["minute"]),
            String.to_integer(match["second"])
          )
        }
    end
  end

  @path_match ~r"""
    ^
    \d{4}s
    /
    (?<year>\d{4})
    (
      /
      \d{4}(?<month>\d{2})
      (
        /
        \d{6}(?<day>\d{2})
        (
          /
          (?<hour>\d{2})
          (?<minute>\d{2})
          (?<second>\d{2})
          \.
          (jpg|jpeg)
        )?
      )?
    )?
  """x

  def parse_path(text) do
    Regex.named_captures(@path_match, text)
    |> then(fn match ->
      if match do
        {
          :ok,
          NaiveDateTime.new!(
            int(match["year"]),
            int(match["month"]) || 1,
            int(match["day"]) || 1,
            int(match["hour"]) || 0,
            int(match["minute"]) || 0,
            int(match["second"]) || 0
          )
        }
      else
        {:error, nil}
      end
    end)
  end

  def set(filename, date_time) do
    destination = "#{filename}.tmp"
    {:ok} = Rewrite.set_date_time(filename, destination, date_time)
    File.rm(filename)
    File.rename(destination, filename)
  end

  defp int(text) do
    case Integer.parse(text) do
      :error ->
        nil

      {value, _} ->
        value
    end
  end
end

root = hd(argv)
glob = Path.join(root, "**/*.{jpg,jpeg}")

Path.wildcard(glob)
|> Enum.map(fn file ->
  relative = Path.relative_to(file, root)
  IO.puts("Processing #{relative}")
  {_, modification_date} = DateSetter.modification_date(file)
  {_, path_date} = DateSetter.parse_path(relative)
  cond do
    path_date == nil ->
      IO.puts "No path date"
    modification_date ->
      IO.puts "Modification date already set: #{modification_date}"
    true ->
      IO.puts "Setting #{path_date}"
      DateSetter.set(file, path_date)
  end
end)
