defmodule Exiffer.CLI do
  @moduledoc """
  Command-line interface for Exiffer.
  """
  use Application

  alias Exiffer.CLI.{Read, SetDateTime, SetGPS}

  @command_definitions [
    %{
      description: "set date and time in image metadata",
      commands: ["set-date-time"],
      switches: [
        source: %{type: :string, required: true, short: :s, description: "Source image"},
        destination: %{type: :string, required: true, short: :d, description: "Destination image"},
        year: %{type: :integer, required: true, short: :t, description: "Year"},
        month: %{type: :integer, short: :m, description: "Month"},
        day: %{type: :integer, short: :d, description: "Day"},
        hour: %{type: :integer, short: :H, description: "Hour"},
        minute: %{type: :integer, short: :M, description: "Minute"},
        second: %{type: :integer, short: :S, description: "Second"}
      ],
      other: nil
    },
    %{
      description: "set GPS coordinates in image metadata",
      commands: ["set-gps"],
      switches: [
        source: %{type: :string, required: true, short: :s, description: "Source image"},
        destination: %{type: :string, required: true, short: :d, description: "Destination image"},
        latitude: %{type: :float, required: true, short: :t, description: "Latitude"},
        longitude: %{type: :float, required: true, short: :n, description: "Longitude"},
        altitude: %{type: :float, short: :a, description: "Altitude"}
      ],
      other: nil
    },
    %{
      description: "read image metadata",
      commands: ["read"],
      switches: [
        filename: %{type: :string, required: true, short: "f", description: "Image filename"},
        format: %{
          type: :string,
          short: :o,
          default: "text",
          description: "Output format ('text' or 'json')"
        },
        quiet: %{
          type: :boolean,
          short: :q,
          default: true,
          description: "Suppress output"
        }
      ],
      other: nil
    }
  ]

  @impl Application
  def start(_type, _args) do
    # Get command line arguments
    args = System.argv()
    exit_code = main(args)
    System.halt(exit_code)
  end

  @spec main([String.t()]) :: 0 | 1
  def main(argv) do
    case HelpfulOptions.parse_commands(argv, @command_definitions) do
      {:ok, ["set-date-time"], switches, _other} ->
        SetDateTime.run(switches)
        0

      {:ok, ["set-gps"], switches, _other} ->
        SetGPS.run(switches)
        0

      {:ok, ["read"], switches, _other} ->
        Read.run(switches)
        0

      {:error, {:unknown_command, []}} ->
        IO.puts(:stderr, "Please supply a command")
        list_top_level_commands()
        1

      {:error, {:unknown_command, commands}} ->
        IO.puts(:stderr, "Unrecognised subcommand: '#{Enum.join(commands, " ")}'")
        list_top_level_commands()
        1

      {:error, error} ->
        IO.puts(:stderr, error)
        list_top_level_commands()
        1
    end
  end

  defp list_top_level_commands do
    help = HelpfulOptions.help_commands!("exiffer", @command_definitions)
    IO.puts(help)
  end
end
