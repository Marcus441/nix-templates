# rust

devenv environment for a minimal production-ready Rust project.

```bash
nix flake init -t 'github:Marcus441/nix-templates#rust'
git init && git add -A
devenv shell               # or: direnv allow
```

## Requirements

**devenv, installed** — https://devenv.sh. There is no `flake.nix` here, so
`nix develop` does not apply. `nix profile install nixpkgs#devenv` is enough.

## What you get

- **the Rust toolchain** via `languages.rust.enable` — cargo, rustc, clippy,
  rustfmt and rust-analyzer, all from one nixpkgs
- a **debugger** — `gdb` on Linux, `lldb` on macOS, since gdb has no
  aarch64-darwin target
- a **tuned release profile** in `Cargo.toml` (LTO, single codegen unit,
  stripped)
- a **`[lints]` policy** in `Cargo.toml`: `unsafe_code` forbidden, clippy's
  pedantic group at warn, `unwrap`/`expect` flagged
- **pkg-config** wired in for crates that link system C libraries
- a **GitHub Actions workflow** that runs `devenv test` on Linux and macOS and
  clippy with `-D warnings`

## Building

```bash
cargo build             # debug
cargo build --release   # optimized production binary
```

The build-shaped proof is `devenv test`, which builds the environment and runs
`cargo test` inside it — the same thing CI holds this template to.

## Testing

```bash
cargo test
cargo clippy
cargo fmt
```

## CI

`.github/workflows/ci.yml` runs `devenv test` on Linux and macOS, and clippy
and rustfmt as a separate Linux job. The split is deliberate: a clippy release
that adds lints should redden the lint job, not the proof that the environment
works.

## Notes

- **Rename the project in `Cargo.toml` alone.** Nothing else here reads the
  crate name — the binary, `cargo test` and CI all follow it.
- `Cargo.lock` is committed on purpose — for binaries this is what makes builds
  reproducible. After adding dependencies run `cargo build` (or `cargo update`)
  to refresh it.
- The lint policy lives in `Cargo.toml`, not in CI flags, so your editor,
  `cargo clippy` and the workflow all agree. Relax a lint there and every one of
  them relaxes with it.
- **`devenv.lock` is not shipped; `devenv update` writes it and you commit it.**
  Write it early. `devenv.yaml` declares one input, but devenv adds *itself* as
  a second and the lock pins both — until then devenv's own modules float, and
  the environment can change behaviour with no edit by you.
- **For editing `devenv.nix` itself, use `devenv lsp`.** It starts nixd already
  configured for this file, using the nixd bundled inside the devenv binary, so
  there is nothing to add to `packages`.
