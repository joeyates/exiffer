# Exiffer

Conveniences for image manipulation.

# Status

Project abandoned as [Vix](https://github.com/akash-akya/vix) wrapper
for libvips covers my needs.

The program now reads almost all image metadata for JPEGs.

In order to modify images, the metadata needs to be written out again,
followed by the image data.

# Debugging

Use `exiftool -htmlDump FILE` to produce an HTML file
with indications of the binary layout.

# Installation

The package can be installed by adding `exiffer` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:exiffer, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/exiffer>.
