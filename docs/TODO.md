# Replace Bakeware with Burrito for Distributable Executables

Status: [ ]

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
