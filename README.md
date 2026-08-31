# nix-templates

Project templates for `nix flake init`. All fourteen are standalone
[devenv](https://devenv.sh) environments: a reproducible dev shell, real
services and processes where a template declares them — started, supervised
and stopped by devenv — and `devenv test` as the one command that proves the
environment works.

## Requirements

Nix, and devenv:

```bash
nix profile install nixpkgs#devenv
```

Every template needs both. None ships a `flake.nix`, so `nix develop` applies
to none of them — `devenv shell` is the door.

Then pick a template:

```bash
nix flake init -t 'github:Marcus441/nix-templates#rust'
```

With no `#name`, you get `devenv` — a minimal environment to fill in.

## Templates

| Template | What you get |
| --- | --- |
| `devenv` | Minimal devenv environment to fill in. The default. |
| `rust` | Minimal production-ready Rust project — clippy, rustfmt, rust-analyzer, gdb |
| `cpp-simple` | C++23 for learning — a plain Makefile, no CMake, no test framework |
| `cpp` | C++23 — CMake + Ninja presets, ASan/UBSan, `ctest` with no test framework |
| `cpp-prod` | Production C++23 — library/exe split, gtest, ASan/UBSan/TSan/coverage profiles, CI |
| `cpp-prod-modern` | As `cpp-prod`, with the library exposed as a C++23 module |
| `ts-node` | Node.js + TypeScript — `tsc` build, vitest |
| `dotnet` | .NET 10 SDK, with F# tooling |
| `python` | Python with uv — ruff, mypy strict, pytest |
| `android-kotlin` | Android with Kotlin and Jetpack Compose; project scaffolded by Google's `android` CLI |
| `typst` | Typst documents, with font plumbing |
| `devenv-postgres` | A local PostgreSQL, started and stopped by devenv |
| `dotnet-react-postgres` | .NET 10 + React + a supervised PostgreSQL — a small monorepo with a shared contracts package |
| `go-react-postgres` | Go + React + a supervised PostgreSQL — the same monorepo shape, spec-first |

`nix flake show github:Marcus441/nix-templates` lists them with descriptions.

Every template ships the same boilerplate — `.editorconfig`, `.envrc`,
`.gitignore` and a `README.md` with a `## Building` section — plus
`devenv.nix` and `devenv.yaml`, every one pinning nixpkgs to the same
`nixos-unstable`. Start from `devenv` if you are filling one in yourself,
`dotnet-react-postgres` if you want a worked example.

## After initialising

`nix flake init` prints what to do next. In short:

```bash
cd my-project
git init && git add -A
devenv shell               # or: direnv allow
```

devenv reads `devenv.nix` and `devenv.yaml` from the working tree, so the
flake-era trap — an untracked file invisible to `nix develop` — is gone. What
remains: the template's own inputs are still flake refs, which Nix resolves
and caches as usual, and the first shell writes state under `.devenv/` — in
the PostgreSQL templates, a live data directory. `git init` first puts the
shipped `.gitignore` in force before that state exists to commit by accident.

## Pinning

Templates ship without a lock, so the first shell resolves current
`nixos-unstable`. Run `devenv update` in your new project to pin it — that
writes `devenv.lock`, the pin is yours, and nothing here moves it afterwards.

Write the lock early. `devenv.yaml` declares one input, but devenv adds
*itself* as a second and the lock pins both — until you write it, devenv's own
service modules float, and the environment can change under you with no edit
on either side.

## Retired templates

Every template here was once a flake — eleven of them, needing nothing but
Nix. Ten were ported to devenv under the same names; `shell` was retired, its
role taken by `devenv`. The last flake state is frozen at the annotated tag
`flake-templates`:

```bash
nix flake init -t 'github:Marcus441/nix-templates/flake-templates#rust'
```

That ref is an escape hatch, not a supported target. The flakes there are
unlocked, so they resolve *current* `nixos-unstable` against templates that
stopped moving at the tag — they will drift, eventually break, and not be
fixed. The harness no longer runs on them.

## Contributing

The repository has its own conventions and a test harness — see `CLAUDE.md`.

```bash
nix flake check              # static checks: registry, spelling, hygiene
./scripts/test-template.sh   # instantiates and tests every template
```
