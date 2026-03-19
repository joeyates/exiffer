# Exiffer

Conveniences for image manipulation.

# Status

This is alpha phase software, use at your peril!

Currently, only handles JPEGs.

# Build

## Prerequisites

- [asdf](https://asdf-vm.com/) version manager
- Zig (for cross-compilation)
- XZ compression utility

## Setup

Install required tools:

```sh
asdf install
```

This will install Zig 0.13.0 as specified in `.tool-versions`.

## Building a Standalone Executable

Build a standalone Linux x86_64 executable:

```sh
MIX_ENV=prod mix release
```

The standalone `exiffer_linux` executable will be created in `burrito_out/`.

# Debugging

Set logging level

```iex
Logger.configure(level: :debug)
```

Do a rewrite without changing anything

```iex
Exiffer.Rewrite.rewrite(path, out, & &1)
```

Use `exiftool -htmlDump FILE > FILE.html` to produce an HTML file
with indications of the binary layout.
