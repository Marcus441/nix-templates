# nix-templates

Project templates for `nix flake init`. Each is standalone and provides a
reproducible dev shell, and in most cases a buildable package. Eleven are
flakes that need nothing but Nix; four are [devenv](https://devenv.sh)
environments, for services a flake cannot supervise.

```bash
nix flake init -t 'github:Marcus441/nix-templates#rust'
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
| `dotnet` | .NET SDK, with F# tooling and a NuGet lock generator |
| `python` | Python with uv — ruff, mypy strict, pytest, `buildPythonApplication` |
| `android-kotlin` | Android with Kotlin and Jetpack Compose; project scaffolded by Google's `android` CLI |
| `typst` | Typst documents, with font plumbing |
| `devenv` | Minimal devenv environment to fill in. **Needs devenv installed** |
| `devenv-postgres` | A local PostgreSQL, started and stopped by devenv. **Needs devenv installed** |
| `dotnet-react-postgres` | .NET 10 + TypeScript + a supervised PostgreSQL, with a `/health` endpoint that queries it. **Needs devenv installed** |
| `go-react-postgres` | Go + TypeScript + a supervised PostgreSQL, with a `/health` endpoint that queries it. **Needs devenv installed** |

`nix flake show github:Marcus441/nix-templates` lists them with descriptions.

Every template ships the same boilerplate — `.editorconfig`, `.envrc`,
`.gitignore` and a `README.md` with a `## Building` section.

The eleven flake templates also share the same flake shape: one `nixpkgs`
input, an explicit `systems` list, a `forAllSystems` helper, and a `formatter`
output so `nix fmt` works in the project you generate.

The four devenv templates are the exception. They ship `devenv.nix` and
`devenv.yaml` instead of a `flake.nix`, so `nix develop` does not apply and you
need devenv on your machine — `nix profile install nixpkgs#devenv`. The trade is
that devenv starts and stops services for you, which a flake dev shell cannot
do. Start from `devenv` if you are filling one in yourself,
`dotnet-react-postgres` if you want a worked example.

## After initialising

`nix flake init` prints what to do next. In short:

```bash
cd my-project
git init && git add -A     # flakes see only tracked files
nix develop                # or `direnv allow`
```

For the devenv templates, that last command is `devenv shell`.

**`git add -A` is not optional.** A flake ignores untracked files, so a fresh
`nix develop` in an un-initialised directory fails with a confusing error about
a missing path.

## Pinning

Templates ship without a lock, so the first `nix develop` resolves current
`nixos-unstable`. Run `nix flake lock` in your new project to pin it — or
`devenv update` in a devenv one, which writes a `devenv.lock`. That pin is
yours, and nothing here moves it afterwards.

Write the devenv lock early. `devenv.yaml` declares one input, but devenv adds
*itself* as a second and the lock pins both — until you write it, devenv's own
service modules float.

`ts-node` also ships a `package-lock.json`, which `nix build` consumes through
`buildNpmPackage` — change a dependency and you refresh both the lock and the
`npmDepsHash` in `flake.nix`. Its README says how.

## Contributing

The repository has its own conventions and a test harness — see `CLAUDE.md`.

```bash
nix flake check              # static checks: registry, spelling, hygiene
./scripts/test-template.sh   # instantiates and tests every template
```
