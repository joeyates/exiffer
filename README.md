# Exiffer

Conveniences for image manipulation.

# Status

This is alpha phase software, use at your peril!

Currently, only handles JPEGs.

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
