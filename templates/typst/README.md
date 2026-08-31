# typst

devenv environment for Typst documents, with fonts wired into the shell so
`typst` can actually see them.

```bash
nix flake init -t 'github:Marcus441/nix-templates#typst'
git init && git add -A
devenv shell               # or: direnv allow
```

## Requirements

**devenv, installed** — https://devenv.sh. There is no `flake.nix` here, so
`nix develop` does not apply. `nix profile install nixpkgs#devenv` is enough.

## What you get

`typst` on `PATH`, and a fontconfig environment built from a list you control.

## Fonts

This is the part that is worth the template. Typst finds fonts through
fontconfig, which in a Nix shell knows nothing unless told. `devenv.nix` builds
a font directory with `linkFarm`, generates a fontconfig file for it with
`makeFontsConf`, and exports it as `FONTCONFIG_FILE`.

To add a font, put it in the one list:

```nix
fonts = [
  pkgs.font-awesome
  pkgs.source-sans
  pkgs.roboto
];
```

Check what Typst can actually see:

```bash
typst fonts
```

If a font you added is missing from that list, it is a fontconfig problem rather
than a Typst one — confirm the package really ships a `.ttf`/`.otf` under
`share/fonts`.

## Building

```bash
typst compile docs/example.typ        # -> docs/example.pdf
typst watch docs/example.typ          # recompile on save
```

The build-shaped command is `devenv test`: it builds the environment, compiles
`docs/example.typ` with the fonts above, and asserts the PDF came out non-empty.
Point `enterTest` in `devenv.nix` at your own documents as they replace the
example.

```bash
devenv test
```

## Notes

- **`devenv.lock` is not shipped; `devenv update` writes it and you commit it.**
  Write it early. `devenv.yaml` declares one input, but devenv adds *itself* as
  a second and the lock pins both — until then devenv's own modules float, and
  the environment can change behaviour with no edit by you.
- **For editing `devenv.nix` itself, use `devenv lsp`.** It starts nixd already
  configured for this file, using the nixd bundled inside the devenv binary, so
  there is nothing to add to `packages`.
- `docs/*.pdf` is gitignored; compiled output is not meant to be committed.
