# Replace Bakeware with Burrito for Distributable Executables

Status: [x]

## Description

Migrate from Bakeware to Burrito for building standalone executable binaries. Burrito is a more actively maintained tool with better cross-platform support and modern features for creating self-contained Elixir applications.

## Technical Specifics

- Update dependency in `mix.exs`: replace `{:bakeware, ...}` with `{:burrito, "~> 1.0"}`
- Modify release configuration in `mix.exs`: replace `steps: [:assemble, &Bakeware.assemble/1]` with Burrito's configuration using the `releases:` keyword and `burrito` options
- Update `lib/exiffer/cli.ex`: replace conditional `use Bakeware.Script` with standard Mix task or escript approach (Burrito doesn't require special script modules)
- Rename and update `docker/bakeware-linux-build.Dockerfile` to reflect new build process
- Update `bin/build` script to use new release paths and commands
- Update build documentation in `README.md`
- Update `mix.lock` by removing bakeware and adding burrito dependencies

# Refactor CLI to use HelpfulOptions.parse_commands/2

Status: [ ]

## Description

Refactor `lib/exiffer/cli.ex` to use the `HelpfulOptions.parse_commands/2` function instead of manually pattern-matching on command names and calling `HelpfulOptions.parse/2` separately for each command. This approach consolidates command definitions into a single data structure and simplifies command routing logic, making it easier to add new commands and maintain the CLI.

The `parse_commands/2` function is designed for CLIs that accept commands and subcommands (like git, mix, or docker), where each command can have its own switches and positional arguments.

## Technical Specifics

- Define a `@command_definitions` module attribute containing all command definitions in the format:
  ```elixir
  @command_definitions [
    %{commands: ["set-date-time"], switches: @set_date_time_switches, other: nil},
    %{commands: ["set-gps"], switches: @set_gps_switches, other: nil},
    %{commands: ["read"], switches: @read_switches, other: nil},
    %{commands: ["help"], switches: nil, other: :any}
  ]
  ```
- Replace the current pattern-matching approach in `main/1` with a single call to `HelpfulOptions.parse_commands(argv, @command_definitions)`
- Update pattern matching to handle the returned `%HelpfulOptions.ParsedCommand{}` struct (or `{:ok, %{commands: [...], switches: %{...}, other: ...}}`)
- Explore using `HelpfulOptions.help_commands/2` or `HelpfulOptions.help_commands!/2` for generating help output
- Ensure all existing CLI commands maintain the same interface and behavior
- Consider whether the help command needs special handling or can be integrated into the command definitions
- Reference: https://github.com/joeyates/helpful_options/blob/main/README.md (section "CLI with commands via `parse_commands/2`")

**Files to modify:**
- `lib/exiffer/cli.ex` (lines 17-127)

**Benefits:**
- More declarative command structure
- Easier to add new commands (just add to the definitions list)
- Reduced boilerplate and duplication
- Better separation of concerns between command definitions and command handling