#!/usr/bin/env elixir

Mix.install(
  [{:exiffer, "~> 0.2.0", path: "."}],
  verbose: true
)

require Logger

alias Exiffer.Rewrite

Logger.configure(level: :info)

argv = System.argv()

if length(argv) != 1 do
  IO.puts("Usage: set_date.exs <path>")
  System.halt(1)
end

defmodule DateSetter do
  @modification_date_match ~r"""
  Modification\sDate:
  \s+
  (?<year>\d{4})
  [-:]
  (?<month>\d{2})
  [-:]
  (?<day>\d{2})
  \s+
  (?<hour>\d{2})
  :
  (?<minute>\d{2})
  :
  (?<second>\d{2})
  """x

  def exif_modification_date(filename) do
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
    (?<decade>\d{3})0s/             # There *must* be the decade, at least
    (
      (?<year>\k<decade>\d)/        # Require the first 3 figures of the YYYY to match the decade
      (
        \k<year>(?<month>\d{2})/    # Require the first 4 figures of the YYYYMM to match the year
        (
          \k<year>\k<month>(?<day>\d{2})/
          (
            (?<hour>\d{2})
            (?<minute>\d{2})
            (?<second>\d{2})
            \.
            (jpg|jpeg)
          )?
        )?
      )?
    )?
  """x

  def path_date(text) do
    Regex.named_captures(@path_match, text)
    |> then(fn match ->
      if match do
        {
          :ok,
          NaiveDateTime.new!(
            int(match["year"]) || int(match["decade"] <> "0"),
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

  def file_modification_date(filename) do
    with {:ok, stat} <- File.stat(filename),
         {:ok, naive} <- NaiveDateTime.from_erl(stat.mtime) do
      {:ok, naive}
    else
      _any ->
        {:error, nil}
    end
  end

  def set_exif(filename, date_time) do
    destination = "#{filename}.tmp"
    :ok = Rewrite.set_date_time(filename, destination, date_time)
    File.rm(filename)
    File.rename(destination, filename)
  end

  @ext4_earliest ~N[1901-12-14 00:00:00]

  def clamp_date_time_to_ext4_range(date_time) do
    case NaiveDateTime.compare(date_time, @ext4_earliest) do
    :lt ->
      @ext4_earliest
    _ ->
      date_time
    end
  end

  def set_file_modification_date(filename, date_time) do
    date_time = clamp_date_time_to_ext4_range(date_time)
    erl_date = date_time |> NaiveDateTime.to_date() |> Date.to_erl()
    erl_time = date_time |> NaiveDateTime.to_time() |> Time.to_erl()
    :ok = File.touch(filename, {erl_date, erl_time})
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
  Logger.info(relative)

  {:ok, path_date} = DateSetter.path_date(relative)

  try do
    {_, exif_modification_date} = DateSetter.exif_modification_date(file)
    {_, file_modification_date} = DateSetter.file_modification_date(file)

    if exif_modification_date do
      Logger.debug("#{relative} - modification date already set: #{exif_modification_date}")
      exif_diff = NaiveDateTime.diff(exif_modification_date, path_date, :day)
      if abs(exif_diff) > 0 do
        Logger.info("#{relative} - wrong date: set #{exif_modification_date}, path #{path_date}, difference #{inspect(exif_diff)} days")
        DateSetter.set_exif(file, path_date)
      end
    else
      Logger.info("#{relative} - will set #{path_date}")
      DateSetter.set_exif(file, path_date)
    end

    clamped_path_date = DateSetter.clamp_date_time_to_ext4_range(path_date)
    file_diff = NaiveDateTime.diff(file_modification_date, clamped_path_date, :day)
    if abs(file_diff) > 365 do
      Logger.info("#{relative} - wrong file modification date: set #{file_modification_date}, path #{path_date}, difference #{inspect(file_diff)} days")
      DateSetter.set_file_modification_date(file, path_date)
    end
  rescue
    error ->
      Logger.error("#{relative} - #{inspect(error)}")
      raise error
  end
end)
