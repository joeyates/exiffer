# bakeware is declared as an optional dependency in `mix.exs`.
# This allows use of exiffer **without** including bakeware.
# Here, we skip any use of Bakeware if it is not present.
if Code.ensure_loaded?(Bakeware.Script) do
  defmodule Exiffer.CLI do
    use Bakeware.Script

    alias Exiffer.CLI.{Read, SetGPS}

    @impl Bakeware.Script
    @spec main([String.t()]) :: 0 | 1
    def main([]) do
      IO.puts(:stderr, "Please supply a command")
      list_top_level_commands()
      1
    end

    @set_gps_switches [
      source: %{type: :string, required: true, short: "s"},
      destination: %{type: :string, required: true, short: "d"},
      latitude: %{type: :float, required: true, short: "t"},
      longitude: %{type: :float, required: true, short: "n"},
      altitude: %{type: :float, short: "a"}
    ]
    def main(["set-gps" | _rest] = args) do
      case HelpfulOptions.parse(args, subcommands: [~w(set-gps)], switches: @set_gps_switches) do
        {:ok, _subcommand, args, []} ->
          SetGPS.run(args)
          0

        {:error, error} ->
          IO.inspect(:stderr, error, [])
          list_top_level_commands()
          1
      end
    end

    @read_switches [
      filename: %{type: :string, required: true, short: "f"}
    ]
    def main(["read" | _rest] = args) do
      case HelpfulOptions.parse(args, subcommands: [~w(read)], switches: @read_switches) do
        {:ok, _subcommand, args, []} ->
          Read.run(args)
          0

        {:error, error} ->
          IO.inspect(:stderr, error, [])
          list_top_level_commands()
          1
      end
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
      IO.puts("exiffer read|set-gps")
    end
  end
end
