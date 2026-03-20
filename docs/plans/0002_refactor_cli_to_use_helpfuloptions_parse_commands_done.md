---
title: Refactor CLI to use HelpfulOptions.parse_commands/2
description: Refactor lib/exiffer/cli.ex to use HelpfulOptions.parse_commands/2 instead of pattern matching and manually calling parse/2 for each command. This consolidates command definitions into a single data structure and simplifies command routing logic.
branch: chore/refactor-cli-parse-commands
---

## Overview

Refactor `lib/exiffer/cli.ex` to use HelpfulOptions.parse_commands/2 instead of pattern matching and manually calling parse/2 for each command. This consolidates command definitions into a single data structure and simplifies command routing logic, making it easier to add new commands and maintain the CLI.

## Tasks

- [x] Define `@command_definitions` module attribute with all command specifications
- [x] Refactor `main/1` to call `parse_commands/2` with unified command definitions
- [x] Update command handlers to work with the new parse result structure
- [x] Replace manual help command implementations with `help_commands!/2`
- [x] Update error handling to work with parse_commands error tuples
- [x] Run existing tests to verify backward compatibility
- [x] Address any additional implementation details that arise during development
- [x] Mark the plan as "done"

## Principal Files

- lib/exiffer/cli.ex — Main CLI module with command routing
- test/exiffer/cli/set_date_time_test.exs — Existing test for set-date-time command
- test/exiffer/cli/read_test.exs — Existing test for read command

## Acceptance Criteria

- All three commands (set-date-time, set-gps, read) maintain their current behavior
- Command definitions are centralized in `@command_definitions`
- Help output is generated using `help_commands!/2` function
- All existing tests pass without modification
- Error messages remain informative and user-friendly
- Code is more maintainable with reduced duplication
