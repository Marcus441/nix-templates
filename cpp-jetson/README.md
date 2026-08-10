# cpp-jetson

Dev environment for C/C++ on the Jetson platform — a host dev shell, an aarch64
cross-compiled binary, and an l4t-based container image.

```bash
nix flake init -t github:Marcus441/nix-templates#cpp-jetson
git init && git add -A     # flakes see only tracked files
nix develop                # or: direnv allow
```

## What you get

| Output | |
| --- | --- |
| `devShells.default` | gcc, cmake, eigen, `ceres-solver.dev` — builds for the host |
| `packages.app-aarch64` | the same source cross-compiled via `pkgsCross.aarch64-multiplatform` |
| `packages.container` | an image layered on `nvcr.io/nvidia/l4t-base`, pinned by digest |

`config.allowUnfree = true` is set inside the flake, so nothing extra is needed
on the command line.

## Building

For the host, inside the dev shell:

```bash
cmake -S . -B build && cmake --build build
```

Cross-compiled, and the container image:

```bash
nix build .#app-aarch64      # aarch64 binary, built on x86_64
nix build .#container        # image to load on the Jetson
```

Neither is proven in CI. The cross build has no binary cache behind it, so it
compiles Eigen, Ceres, g2o and SuiteSparse from source, and the container needs
a registry pull from `nvcr.io`. Expect the first `nix build .#app-aarch64` to
take a long time.

Cross-compilation is emulation-free — it is a real aarch64 toolchain — but
anything that runs a build-time binary needs the `nativeBuildInputs` /
`buildInputs` split to be right. `nativeBuildInputs` are host tools (cmake,
pkg-config); `buildInputs` are aarch64 libraries. The compiler comes from
`pkgsArm.stdenv` and does not belong in either list.

## Testing

The cross build sets `-DBUILD_TESTING=OFF`: a test binary compiled for aarch64
cannot run on the x86_64 machine that built it. Test on the host toolchain in
the dev shell, or on the Jetson itself.

## Notes

- `CMakeLists.txt` calls `find_package(g2o REQUIRED)`, so `pkgsArm.g2o` is in
  `buildInputs`. Drop both together if you do not need g2o — a `find_package`
  with no matching input fails at configure time, not at evaluation, so the
  flake looks fine right up until you build it.
- **Keeping the l4t pin current.** The base image is pinned by digest and
  sha256, both spelled out in `flake.nix`. The identical block appears in the
  `python-jetson` template; templates are copied verbatim and cannot share code,
  so **a fix to one is a fix to both**.
- `nix2container` follows this flake's `nixpkgs`, so the lock carries one
  nixpkgs rather than two.
- `.envrc` adds `build` to `PATH`.
- `nix fmt` formats `flake.nix` with alejandra.
