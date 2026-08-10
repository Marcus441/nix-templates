# python-jetson

Python for the NVIDIA Jetson platform — a host dev shell, an aarch64
cross-compiled application, and an l4t-based container image.

> **Known broken, in two ways.** `packages.<system>.arm64.app` nests one level
> deeper than the flake schema allows, so `nix flake check` rejects this flake;
> and `pyproject.toml` is empty while the flake builds it with
> `format = "pyproject"`. Both are tracked in this repository's issue tracker.
> The dev shell itself works.

```bash
nix flake init -t github:Marcus441/nix-templates#python-jetson
git init && git add -A     # flakes see only tracked files
nix develop
```

## What you get

| Output | |
| --- | --- |
| `devShells.default` | python313 with pip, setuptools, wheel, numpy, pyyaml |
| `packages.arm64.app` | `buildPythonApplication` cross-compiled to aarch64 |
| `packages.container` | an image layered on `nvcr.io/nvidia/l4t-base`, pinned by digest |

`config.allowUnfree = true` is set inside the flake.

## Layout

```
src/jetson_project/    the package
configuration/         runtime config
models/                model weights (not committed)
data/                  datasets (not committed)
tests/
nix/
```

## Before `packages.arm64.app` will build

`pyproject.toml` needs a real `[build-system]` and `[project]` table. Choosing
the backend and pinning a numpy/opencv set that genuinely cross-compiles to
aarch64 is the actual work — the empty file is a placeholder, not a default.

## Keeping the l4t pin current

The base image is pinned by digest and sha256 in `flake.nix`. The identical
block appears in the `cpp-jetson` template; templates are copied verbatim and
cannot share code, so **a fix to one is a fix to both**.
