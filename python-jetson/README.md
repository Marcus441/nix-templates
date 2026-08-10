# python-jetson

Dev environment for Python on the Jetson platform — a host dev shell, an aarch64
cross-compiled application, and an l4t-based container image.

> **Known broken, in two ways.** `packages.<system>.arm64.app` nests one level
> deeper than the flake schema allows, so `nix flake check` rejects this flake;
> and `pyproject.toml` is empty while the flake builds it with
> `format = "pyproject"`. Both are tracked in this repository's issue tracker.
> The dev shell itself works.

```bash
nix flake init -t github:Marcus441/nix-templates#python-jetson
git init && git add -A     # flakes see only tracked files
nix develop                # or: direnv allow
```

## What you get

| Output | |
| --- | --- |
| `devShells.default` | python313 with pip, setuptools, wheel, numpy, pyyaml |
| `packages.arm64.app` | `buildPythonApplication` cross-compiled to aarch64 |
| `packages.container` | an image layered on `nvcr.io/nvidia/l4t-base`, pinned by digest |

`config.allowUnfree = true` is set inside the flake, so nothing extra is needed
on the command line.

## Layout

```
src/jetson_project/    the package
configuration/         runtime config
models/                model weights (not committed)
data/                  datasets (not committed)
tests/
nix/
```

## Building

Inside the dev shell, run the code directly:

```bash
python -m jetson_project.main
```

Cross-compiled, and the container image:

```bash
nix build .#arm64.app        # aarch64 application, built on x86_64
nix build .#container        # image to load on the Jetson
```

`pyproject.toml` needs a real `[build-system]` and `[project]` table before
`packages.arm64.app` will build. Choosing the backend and pinning a
numpy/opencv set that genuinely cross-compiles to aarch64 is the actual work —
the empty file is a placeholder, not a default.

## Testing

Tests live in `tests/`. Run them on the host toolchain in the dev shell, or on
the Jetson itself; an aarch64 build cannot run its own tests on the x86_64
machine that produced it.

## Notes

- **Keeping the l4t pin current.** The base image is pinned by digest and
  sha256, both spelled out in `flake.nix`. The identical block appears in the
  `cpp-jetson` template; templates are copied verbatim and cannot share code, so
  **a fix to one is a fix to both**.
- `nix2container` follows this flake's `nixpkgs`, so the lock carries one
  nixpkgs rather than two.
- `nix fmt` formats `flake.nix` with alejandra.
