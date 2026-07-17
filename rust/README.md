# Project Name

A minimal, production-ready Rust project template.

## Features
- **Cargo** with a tuned release profile (LTO, single codegen unit, stripped)
- **clippy**, **rustfmt**, **rust-analyzer** and **gdb** in the dev shell
- **pkg-config** wired in for crates that link system C libraries (add the
  libraries themselves to `buildInputs`)
- **Nix Flake** for a reproducible hermetic environment (tests run as part
  of `nix build`)

## Prerequisites
- [Nix](https://nixos.org/download.html) (with flakes enabled)
- *Optional but recommended:* [direnv](https://direnv.net/)

## Development Setup

Enter the reproducible development shell:
```bash
nix develop
```
*(If using `direnv`, simply run `direnv allow`)*

## Building

```bash
cargo build             # debug
cargo build --release   # optimized production binary
```

Or build the Nix package (compiles in a sandbox and runs the tests):
```bash
nix build
```

## Testing & Linting

```bash
cargo test
cargo clippy
cargo fmt
```

## Notes
- Rename the project in `Cargo.toml` and `flake.nix` (`project = ...`).
- `Cargo.lock` is committed on purpose -- for binaries this is what makes
  builds reproducible. After adding dependencies, run `cargo build` (or
  `cargo update`) to refresh it; the Nix build reads it via
  `cargoLock.lockFile`.
