# python-jetson

Dev environment for Python on the Jetson platform — a host dev shell, an aarch64
cross-compiled application, and an l4t-based container image.

```bash
nix flake init -t github:Marcus441/nix-templates#python-jetson
git init && git add -A     # flakes see only tracked files
nix develop                # or: direnv allow
```

## What you get

| Output | |
| --- | --- |
| `devShells.default` | python313 with pip, setuptools, wheel, numpy, pyyaml |
| `packages.app-aarch64` | `buildPythonApplication` cross-compiled to aarch64 |
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
nix build .#app-aarch64      # aarch64 application, built on x86_64
nix build .#container        # image to load on the Jetson
```

Neither is proven in CI. Cross-compiling the Python stack has no binary cache
behind it, and the container needs a registry pull from `nvcr.io`.

`pyproject.toml` declares a setuptools backend, `src/` layout and a
`jetson-python-app` console script — which is the name the container's `Cmd`
invokes, so rename both together. `numpy` and `pyyaml` are declared as
dependencies; `opencv4` is supplied by Nix through `propagatedBuildInputs`
rather than pinned in `pyproject.toml`, because the nixpkgs build is the one
that actually cross-compiles.

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
