---
paths: "*/flake.nix"
---

# Writing a template's flake.nix

A template flake is read by someone who has never seen this repo, and copied
into a project that has no relationship to it. Optimise for that reader.

## The canonical preamble

Every template opens the same way. Deviating from it fails the `nixpkgs-pin`
check and, more importantly, teaches the reader a second idiom for no reason.

```nix
{
  description = "<one line — required, and shown by `nix flake init -t`>";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [];
      };
    });
}
```

Take `self` as the first argument **only** when it is used —
`inputsFrom = [self.packages.${system}.default]` is the usual reason.

## Rules

- **Keep the `...` ellipsis** in the `outputs` argument set. Without it, adding
  any input is a breaking change to the consumer's flake.
  `android-kotlin/flake.nix` is the one template missing it (CLAUDE.md §7).
- **Never reference a path outside the template directory.** No `../`, no
  `../../lib`. `nix flake init` copies this directory alone and the reference
  would dangle in every generated project. This is Inv. 1 and it is the reason
  duplication between templates cannot be refactored away.
- **Never introduce flake-parts, import-tree, devenv or snowfall.** The registry
  uses flake-parts; a template must not. A generated project should not inherit
  a framework it did not ask for.
- **No eager reads of files the template does not ship.**
  `builtins.readFile ./nix/deps.nix` at eval time makes the template
  un-evaluatable as shipped — this is exactly the `dotnet` bug. If an output
  depends on a file the *user* generates, guard it:

  ```nix
  packages = lib.optionalAttrs (builtins.pathExists ./nix/deps.nix) {
    default = ...;
  };
  ```

- **A build output must build in the sandbox** — no network. `cpp/flake.nix` is
  the example to copy: gtest via `checkInputs` plus
  `-DFETCHCONTENT_FULLY_DISCONNECTED=ON`, rather than CMake `FetchContent`
  reaching for the network at build time.

## Before you finish

- The template also needs `.envrc` (`use flake`), `.gitignore` and `README.md`.
- The registry needs an entry — `meta/templates.nix`, and see the
  **add-template** skill.
- **Run the harness.** `./scripts/test-template.sh <name>`. Reading the flake is
  not evidence that it instantiates.
