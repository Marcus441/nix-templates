# rust

Dev environment for a minimal production-ready Rust project.

```bash
nix flake init -t github:Marcus441/nix-templates#rust
git init && git add -A     # flakes see only tracked files
nix develop                # or: direnv allow
```

## What you get

- **Cargo** with a tuned release profile (LTO, single codegen unit, stripped)
- **clippy**, **rustfmt**, **rust-analyzer** and **gdb** in the dev shell
- **pkg-config** wired in for crates that link system C libraries — add the
  libraries themselves to `buildInputs`
- a `packages.default` built by `buildRustPackage`, with `cargo test` running in
  its check phase

## Building

```bash
cargo build             # debug
cargo build --release   # optimized production binary
```

Or build the Nix package, which compiles in a sandbox and runs the tests:

```bash
nix build
nix run                 # runs the built binary
```

## Testing

```bash
cargo test
cargo clippy
cargo fmt
```

## Notes

- Rename the project in `Cargo.toml` and in `flake.nix` (`project = ...`). The
  two must agree: `meta.mainProgram` is what makes `nix run` work, and it has to
  name the binary Cargo actually produces.
- `Cargo.lock` is committed on purpose — for binaries this is what makes builds
  reproducible. After adding dependencies run `cargo build` (or `cargo update`)
  to refresh it; the Nix build reads it via `cargoLock.lockFile`.
- The dev shell takes `inputsFrom = [self.packages.<system>.default]`, so any
  system library you add to the package is present in the shell too — one place
  to declare it, not two.
- `nix fmt` formats `flake.nix` with alejandra.
