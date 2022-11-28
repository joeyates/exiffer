# Exiffer

Conveniences for image manipulation.

# Build

Create a (reasonable) portable Linux build:

```sh
podman build --file docker/bakeware-linux-build.Dockerfile --tag exiffer:latest .
podman run -v `pwd`:/app/_build/prod/rel/bakeware -e MIX_ENV=prod -ti exiffer:latest mix release
```

The `exiffer` executable will be built in the project root.

# Debugging

Use `exiftool -htmlDump FILE` to produce an HTML file
with indications of the binary layout.
