# bakeware is declared as an optional dependency in `mix.exs`.
# This allows use of exiffer **without** including bakeware.
# Here, we skip any use of Bakeware if it is not present.
if Code.ensure_loaded?(Bakeware.Script) do
  defmodule Exiffer.CLI do
    use Bakeware.Script

    alias Exiffer.CLI.{Read, SetDateTime, SetGPS}

    @impl Bakeware.Script
    @spec main([String.t()]) :: 0 | 1
    def main([]) do
      IO.puts(:stderr, "Please supply a command")
      list_top_level_commands()
      1
    end

    @set_date_time_switches [
      source: %{type: :string, required: true, short: :s, description: "Source image"},
      destination: %{type: :string, required: true, short: :d, description: "Destination image"},
      year: %{type: :integer, required: true, short: :t, description: "Year"},
      month: %{type: :integer, short: :m, description: "Month"},
      day: %{type: :integer, short: :d, description: "Day"},
      hour: %{type: :integer, short: :H, description: "Hour"},
      minute: %{type: :integer, short: :M, description: "Minute"},
      second: %{type: :integer, short: :S, description: "Second"}
    ]
    def main(["set-date-time" | rest]) do
      case HelpfulOptions.parse(rest, switches: @set_date_time_switches) do
        {:ok, args, []} ->
          SetDateTime.run(args)
          0

        {:error, error} ->
          IO.puts(:stderr, error)
          list_top_level_commands()
          1
      end
    end

    @set_gps_switches [
      source: %{type: :string, required: true, short: :s, description: "Source image"},
      destination: %{type: :string, required: true, short: :d, description: "Destination image"},
      latitude: %{type: :float, required: true, short: :t, description: "Latitude"},
      longitude: %{type: :float, required: true, short: :n, description: "Longitude"},
      altitude: %{type: :float, short: :a, description: "Altitude"}
    ]
    def main(["set-gps" | rest]) do
      case HelpfulOptions.parse(rest, switches: @set_gps_switches) do
        {:ok, args, []} ->
          SetGPS.run(args)
          0

        {:error, error} ->
          IO.puts(:stderr, error)
          list_top_level_commands()
          1
      end
    end

    def main(["help", "set-gps"]) do
      switches = HelpfulOptions.help!(switches: @set_gps_switches)
      IO.puts(
        """
        NAME
          exiffer set-gps - set GPS coordinates in image metadata

        OPTIONS
        #{switches}
        """
      )
    end

    @read_switches [
      filename: %{type: :string, required: true, short: "f", description: "Image filename"},
      format: %{type: :string, short: :o, default: "text", description: "Output format ('text' or 'json')"},
      quiet: %{type: :boolean, short: :q, default: true, description: "Suppress output"}
    ]
    def main(["read" | rest]) do
      case HelpfulOptions.parse(rest, switches: @read_switches) do
        {:ok, args, []} ->
          Read.run(args)
          0

        {:error, error} ->
          IO.puts(:stderr, error)
          list_top_level_commands()
          1
      end
    end

    def main(["help", "read"]) do
      switches = HelpfulOptions.help!(switches: @read_switches)
      IO.puts(
        """
        NAME
          exiffer read - read image metadata

        OPTIONS
        #{switches}

        By default `--quiet` is set to `true` in order to not create confusing output.
        If you want logging output, pass the `--no-quiet` flag.
        """
      )
    end

    def main(["help" | _args]) do
      list_top_level_commands()
      0
    end

    def main(args) do
      IO.puts(:stderr, "Unrecognised subcommand: '#{Enum.join(args, " ")}'")
      1
    end

    defp list_top_level_commands do
      IO.puts("exiffer read|set-date-time|set-gps")
    end
  end
end
