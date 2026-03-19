---
title: Replace Bakeware with Burrito for Distributable Executables
description: Migrate from Bakeware to Burrito for building standalone executable binaries, providing better cross-platform support and modern features. The simpler Burrito approach eliminates the need for Docker-based builds and custom build scripts.
branch: feature/replace-bakeware-with-burrito
---

## Overview

This plan involves replacing the Bakeware build system with Burrito for creating standalone executables. Burrito provides better cross-platform support and can be built directly with `MIX_ENV=prod mix release` without Docker or custom scripts. The main changes include updating dependencies, modifying the CLI module to work without Bakeware.Script, configuring Burrito for Linux x86_64 builds, and cleaning up obsolete build infrastructure. Burrito requires Zig and XZ as build-time dependencies, which will be managed via asdf.

## Tasks

- [x] Update `mix.exs` dependencies: replace `{:bakeware, ...}` with `{:burrito, "~> 1.0"}`
- [x] Refactor `mix.exs` application function to remove EXIFFER_BUILD_CLI environment variable check
- [x] Refactor `lib/exiffer/cli.ex` to remove conditional Bakeware.Script usage and implement standard application startup
- [x] Configure Burrito release in `mix.exs` with target `linux: [os: :linux, cpu: :x86_64]`
- [x] Run `mix deps.get` to fetch Burrito and update `mix.lock`
- [x] Create `.tool-versions` file with Zig 0.13.0
- [x] Remove `docker/` directory (no longer needed)
- [x] Remove `bin/build` script (builds done via mix task)
- [x] Check for and remove any other obsolete files related to Bakeware builds
- [x] Update build documentation in `README.md` to document asdf as a dependency, `asdf install` command, Zig and XZ requirements, and the simplified `MIX_ENV=prod mix release` process
- [x] Test local build with `MIX_ENV=prod mix release` to ensure executable is created successfully
- [ ] Verify executable runs correctly with test commands
- [ ] Address any additional implementation details that arise during development
- [ ] Mark the plan as "done"

## Principal Files

- `mix.exs` - Dependencies, application function, and Burrito release configuration
- `lib/exiffer/cli.ex` - CLI module that currently uses Bakeware.Script
- `.tool-versions` - To be created with Zig 0.15.2
- `README.md` - Build documentation (including asdf, Zig and XZ dependencies)
- `mix.lock` - Dependencies lock file
- `docker/` - Directory to be removed
- `bin/build` - To be removed

## Acceptance Criteria

- The project successfully builds a standalone executable using Burrito with `MIX_ENV=prod mix release`
- The executable runs on Linux x86_64 without requiring Erlang/Elixir installation
- All CLI commands (set-date-time, set-gps, read, help) work correctly in the new executable
- `.tool-versions` file contains Zig 0.15.2
- `mix.exs` no longer checks for EXIFFER_BUILD_CLI environment variable
- Build documentation accurately describes the simplified build process and lists asdf as a dependency with `asdf install` instructions
- Build documentation lists Zig and XZ as build-time dependencies
- Docker directory and custom build script have been removed
- All obsolete Bakeware-related files have been identified and removed
- No Bakeware dependencies remain in the codebase
- Build process is simpler and only requires standard mix commands
