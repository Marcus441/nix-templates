# rust

Dev environment for a minimal production-ready Rust project.

```bash
nix flake init -t 'github:Marcus441/nix-templates#rust'
git init && git add -A     # flakes see only tracked files
nix develop                # or: direnv allow
```

## What you get

- **Cargo** with a tuned release profile (LTO, single codegen unit, stripped)
- **clippy**, **rustfmt**, **rust-analyzer** and a debugger in the dev shell —
  `gdb` on Linux, `lldb` on macOS, since gdb has no aarch64-darwin target
- a **`[lints]` policy** in `Cargo.toml`: `unsafe_code` forbidden, clippy's
  pedantic group at warn, `unwrap`/`expect` flagged
- **pkg-config** wired in for crates that link system C libraries
- a `packages.default` built by `buildRustPackage`, with `cargo test` running in
  its check phase
- a **GitHub Actions workflow** that builds on Linux and macOS and runs clippy
  with `-D warnings`

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

- **Rename the project in `Cargo.toml` alone.** The flake reads `[package]` out
  of it with `builtins.fromTOML`, so `pname`, `version` and `meta.mainProgram`
  all follow — and `mainProgram`, which is what makes `nix run` work, cannot
  drift from the binary Cargo actually produces.
- `Cargo.lock` is committed on purpose — for binaries this is what makes builds
  reproducible. After adding dependencies run `cargo build` (or `cargo update`)
  to refresh it; the Nix build reads it via `cargoLock.lockFile`.
- The dev shell takes `inputsFrom = [self.packages.<system>.default]`, so any
  system library you add to the package's `buildInputs` is present in the shell
  too — one place to declare it, not two.
- The lint policy lives in `Cargo.toml`, not in CI flags, so your editor,
  `cargo clippy` and the workflow all agree. Relax a lint there and every one of
  them relaxes with it.
- `nix fmt` formats `flake.nix` with alejandra.
