# typst

Dev environment for Typst documents, with fonts wired into the shell so `typst`
can actually see them.

```bash
nix flake init -t github:Marcus441/nix-templates#typst
git init && git add -A     # flakes see only tracked files
nix develop                # or: direnv allow
typst watch docs/example.typ
```

## What you get

`typst` on `PATH`, and a fontconfig environment built from a list you control.

## Fonts

This is the part that is worth the template. Typst finds fonts through
fontconfig, which in a Nix shell knows nothing unless told. `flake.nix` builds a
font directory with `linkFarm`, generates a fontconfig file for it with
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

There is no `packages` output — a document is not a package. Add one with
`pkgs.stdenv.mkDerivation` calling `typst compile` if you want the PDF built by
`nix build`; remember to pass `FONTCONFIG_FILE` there too, since a build sandbox
does not inherit the dev shell's environment.

## Notes

- `nix fmt` formats `flake.nix` with alejandra.
- `docs/*.pdf` is gitignored; compiled output is not meant to be committed.
