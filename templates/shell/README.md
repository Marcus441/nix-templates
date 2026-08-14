# shell

Minimal dev shell to fill in. This is the default template — `nix flake init`
with no `-t` copies it.

```bash
nix flake init -t 'github:Marcus441/nix-templates#shell'
git init && git add -A     # flakes see only tracked files
nix develop                # or: direnv allow
```

## What you get

A `flake.nix` with one empty dev shell, and the boilerplate every template in
this collection ships: `.editorconfig`, `.envrc`, `.gitignore` and this file.

Reach for one of the language templates instead if there is one — they come
with a build output and the language's tooling already wired up.

## Filling it in

Add packages to the empty list in `flake.nix`:

```nix
devShells = forAllSystems (pkgs: {
  default = pkgs.mkShell {
    name = "shell";
    packages = [
      pkgs.ripgrep
      pkgs.jq
    ];
  };
});
```

Search for names with `nix search nixpkgs <term>`, or on
[search.nixos.org](https://search.nixos.org/packages).

## Building

There is nothing to build yet — this template has no `packages` output. To add
one, put a derivation next to the dev shell:

```nix
packages = forAllSystems (pkgs: {
  default = pkgs.stdenv.mkDerivation {
    pname = "myproject";
    version = "0.1.0";
    src = ./.;
  };
});
```

`nix build` then builds it, and `nix run` runs it if you also set
`meta.mainProgram` to the binary's name.

## Notes

- `nix fmt` formats `flake.nix` with alejandra.
- `.envrc` ships with `use flake`, so `direnv allow` enters the shell
  automatically on `cd`.
- The `systems` list at the top of `flake.nix` is the set of platforms this
  flake claims to work on. Trim it rather than leaving a claim you cannot test.
