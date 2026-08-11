# nix-templates

Project templates for `nix flake init`. Each is a standalone flake providing a
reproducible dev shell, and in most cases a buildable package.

```bash
nix flake init -t github:Marcus441/nix-templates#rust
```

With no `#name`, you get `shell` — a minimal dev shell to fill in.

## Templates

| Template | What you get |
| --- | --- |
| `shell` | Minimal dev shell to fill in. The default. |
| `rust` | Minimal production-ready Rust project — `buildRustPackage`, clippy, rustfmt, rust-analyzer, gdb |
| `cpp-simple` | C++23 for learning — a plain Makefile, no CMake, no test framework |
| `cpp` | C++23 — CMake + Ninja presets, ASan/UBSan, `ctest` with no test framework |
| `cpp-prod` | Production C++23 — library/exe split, gtest, ASan/UBSan/TSan/coverage profiles, CI |
| `cpp-prod-modern` | As `cpp-prod`, with the library exposed as a C++23 module |
| `ts-node` | Node.js + TypeScript — `tsc` build, vitest, `buildNpmPackage` |
| `ts-node-rest-api` | TypeScript REST API — Express 5 middleware layout, vitest |
| `dotnet` | .NET SDK, with F# tooling and a NuGet lock generator |
| `android-kotlin` | Android with Kotlin and Jetpack Compose; project scaffolded by Google's `android` CLI |
| `typst` | Typst documents, with font plumbing |

`nix flake show github:Marcus441/nix-templates` lists them with descriptions.

Every template ships the same boilerplate — `.editorconfig`, `.envrc`,
`.gitignore` and a `README.md` with a `## Building` section — and the same flake
shape: one `nixpkgs` input, an explicit `systems` list, a `forAllSystems`
helper, and a `formatter` output so `nix fmt` works in the project you generate.

## After initialising

`nix flake init` prints what to do next. In short:

```bash
cd my-project
git init && git add -A     # flakes see only tracked files
nix develop                # or `direnv allow`
```

**`git add -A` is not optional.** A flake ignores untracked files, so a fresh
`nix develop` in an un-initialised directory fails with a confusing error about
a missing path.

## Pinning

Templates ship without a `flake.lock`, so the first `nix develop` resolves
current `nixos-unstable`. Run `nix flake lock` in your new project to pin it —
that pin is yours, and nothing here moves it afterwards.

`ts-node` and `ts-node-rest-api` also ship a `package-lock.json`, which
`nix build` consumes through `buildNpmPackage` — change a dependency and you
refresh both the lock and the `npmDepsHash` in `flake.nix`. Their READMEs say
how.

## Contributing

The repository has its own conventions and a test harness — see `CLAUDE.md`.

```bash
nix flake check              # static checks: registry, spelling, hygiene
./scripts/test-template.sh   # instantiates and tests every template
```
