---
paths: "*/flake.nix"
---

# Writing a template's flake.nix

A template flake is read by someone who has never seen this repo, and copied
into a project that has no relationship to it. Optimise for that reader.

## The canonical preamble

Every template opens the same way. Deviating from it fails `checks.flake-inputs`
and, more importantly, teaches the reader a second idiom for no reason.

```nix
{
  description = "<one line — must be the registry's description, verbatim>";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {nixpkgs, ...}: let
    systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
    forAllSystems = f:
      nixpkgs.lib.genAttrs systems (
        system: f (import nixpkgs {inherit system;})
      );
  in {
    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        name = "<template-name>";
        packages = [];
      };
    });

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}
```

Take `self` as the first argument **only** when it is used —
`inputsFrom = [self.packages.${pkgs.system}.default]` is the usual reason. Note
`pkgs.system`: `forAllSystems` passes `pkgs`, not `system`, so that the helper
is one argument in all thirteen templates. Alejandra collapses `{nixpkgs, ...}`
onto one line and expands `{self, nixpkgs, ...}`; let it, and never hand-format
against it — `checks.treefmt` is the arbiter.

`docs/decisions/no-flake-utils.md` records why the helper is written out rather
than imported, and why it cannot be shared.

## Rules

- **`systems` must equal the template's registry `systems`.** `flake-inputs`
  renders the expected line from `meta/templates.nix` and greps for it, so a
  narrowed template says so in the artifact and not only in `meta/`.
- **Never introduce `flake-utils`,** or flake-parts, import-tree, devenv or
  snowfall. The registry uses flake-parts; a template must not. A generated
  project should not inherit a framework it did not ask for.
- **Keep the `...` ellipsis** in the `outputs` argument set. Without it, adding
  any input is a breaking change to the consumer's flake. Checked.
- **Never reference a path outside the template directory.** No `../`, no
  `../../lib`. `nix flake init` copies this directory alone and the reference
  would dangle in every generated project. This is Inv. 1 and it is the reason
  duplication between templates cannot be refactored away.
- **`description` must equal the registry's.** `nix flake init -t` prints the
  registry's and the consumer then reads the flake's; two sentences for one
  template is one too many. Checked by `description-agrees`.
- **No comments.** A template is documentation for a stranger, and the README is
  where that belongs — a reader skimming `flake.nix` should see the shape, not
  prose. Anything worth saying goes in the template's `README.md`, under
  `Notes`.
- **No `shellHook` banners.** They cost a subprocess on every `nix develop` and
  every direnv reload, and the version they echo is already in the README. If a
  hook does real work, it may stay; decoration may not.
- **One spelling per job.** Dev-shell dependencies go in `packages`, never
  `buildInputs` or `nativeBuildInputs`. Environment variables go in `env = {…}`,
  never as bare top-level attributes. No `with pkgs;` — least of all
  `with pkgs; []`.
- **`mkShellNoCC`** when nothing in the shell needs a C compiler; `mkShell`
  otherwise.
- **`meta.mainProgram`** on any `packages.default` that produces a binary, so
  `nix run` works in the generated project. It is the *binary* name, which is
  not always `pname` — `cpp` builds `my-project` from `pname = "myproject"`.
- **Unfree or licence-gated packages:** set it in the flake, inside the
  `import nixpkgs` call, so the consumer never needs `--impure`. The registry's
  `unfree` flag is only for templates that do *not* do this, and no template
  currently needs it.
- **No eager reads of files the template does not ship.**
  `builtins.readFile ./nix/deps.nix` at eval time makes the template
  un-evaluatable as shipped. If an output depends on a file the *user*
  generates, guard it — `dotnet` is the worked example:

  ```nix
  packages = forAllSystems (pkgs:
    nixpkgs.lib.optionalAttrs (depsFile != null) {
      default = ...;
    });
  ```

- **A build output must build in the sandbox** — no network. `cpp/flake.nix` is
  the example to copy: gtest via `checkInputs` plus
  `-DFETCHCONTENT_FULLY_DISCONNECTED=ON`, rather than CMake `FetchContent`
  reaching for the network at build time.

## Before you finish

- The template also needs `.editorconfig`, `.envrc`, `.gitignore` and
  `README.md`, and the `.gitignore` must open with the four-line Nix block. All
  checked by `template-hygiene`.
- The registry needs an entry — `meta/templates.nix`, and see the
  **add-template** skill.
- **Run the harness.** `./scripts/test-template.sh <name>`. Reading the flake is
  not evidence that it instantiates.
