# typst

Typst document environment, with fonts wired into the shell so `typst` can
actually see them.

```bash
nix flake init -t github:Marcus441/nix-templates#typst
git init && git add -A     # flakes see only tracked files
nix develop
typst watch docs/example.typ
```

## Fonts

This is the part that is worth the template. Typst finds fonts through
fontconfig, which in a Nix shell knows nothing unless told. `flake.nix` builds a
font directory with `linkFarm`, generates a fontconfig file for it with
`makeFontsConf`, and exports it as `FONTCONFIG_FILE`.

To add a font, put it in the one list:

```nix
fonts = with pkgs; [
  font-awesome
  source-sans
  roboto
];
```

The shell hook runs `typst fonts` on entry so a missing font is visible
immediately rather than at compile time.

## Building

```bash
typst compile docs/example.typ        # -> docs/example.pdf
typst watch docs/example.typ          # recompile on save
```

There is no `packages` output — a document is not a package. Add one with
`pkgs.stdenv.mkDerivation` calling `typst compile` if you want the PDF built by
`nix build`.
