# shell

A minimal dev shell to fill in. This is the default template — `nix flake init`
with no `-t` copies it.

```bash
nix flake init -t github:Marcus441/nix-templates#shell
git init && git add -A     # flakes see only tracked files
nix develop
```

## Filling it in

Add packages to the empty list in `flake.nix`:

```nix
devShells.default = pkgs.mkShell {
  packages = with pkgs; [
    ripgrep
    jq
  ];
};
```

Search for names with `nix search nixpkgs <term>`, or on
[search.nixos.org](https://search.nixos.org/packages).

Reach for one of the language templates instead if there is one — they come
with a build output, a formatter and editor config already wired up.

## direnv

`.envrc` ships with `use flake`, so `direnv allow` enters the shell
automatically on `cd`.
