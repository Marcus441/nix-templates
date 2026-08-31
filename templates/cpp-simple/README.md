# cpp-simple

devenv environment for learning C++ with a plain Makefile. The lowest rung of
the C++ ladder: a compiler, a debugger-friendly build, and nothing else to
read.

```bash
nix flake init -t 'github:Marcus441/nix-templates#cpp-simple'
git init && git add -A
devenv shell               # or: direnv allow
```

## Requirements

**devenv, installed** — https://devenv.sh. There is no `flake.nix` here, so
`nix develop` does not apply. `nix profile install nixpkgs#devenv` is enough.

## What you get

- **C++23** with the platform's default compiler — `g++` on Linux, `clang++` on
  macOS, both reached through `c++`
- **A Makefile you can read in a minute**, with explicit compile and link rules
- `clangd`, `clang-format` and `clang-tidy`, so the editor works without a
  generated compilation database
- **`cpplint`** with a `CPPLINT.cfg` that matches the 100-column formatting

There is deliberately no CMake, no test framework, no sanitizer option and no
build profiles. When you want those, move up a rung: `cpp` adds CMake, presets
and sanitizers; `cpp-prod` adds GoogleTest, a library/executable split and CI.

## Building

```bash
make            # compile and link
make run        # build, then run it
make clean      # remove build/ and the binary
```

The proof is `devenv test`: it builds the environment, runs `make` and
executes the binary.

## Linting

```bash
clang-format -i src/*.cpp     # format in place
cpplint src/*.cpp             # style check, configured by CPPLINT.cfg
```

## Testing

There is no test suite at this rung — that is the point. `cpp` adds `ctest`
with plain `assert`-based tests and no external dependency; `cpp-prod` adds
GoogleTest.

## Notes

- **The Makefile is the lesson.** It compiles each `src/*.cpp` to its own object
  file in `build/`, then links them into one binary, so the two steps every C++
  build system hides are visible and separately re-runnable. Adding a source
  file needs no edit — `$(wildcard src/*.cpp)` picks it up.
- **The compiler is named in `packages`.** A `nix develop` shell would carry
  one implicitly, through `mkShell`'s stdenv; a devenv shell does not, so
  `devenv.nix` picks the platform's own — `gcc` on Linux, `clang` on macOS,
  the same choice stdenv makes. Both wrappers put `c++` on `PATH`, which is
  what the Makefile calls.
- **`CXX` and `CXXFLAGS` use `?=`,** so anything already in the environment
  wins and `make CXXFLAGS=...` still overrides everything. Unset, `CXX` falls
  back to `c++` rather than to make's built-in `g++` — which is what keeps one
  Makefile correct on both platforms.
- **`.clangd` is doing real work here.** With no CMake there is no
  `compile_commands.json`, so without it `clangd` would not know the language
  standard and would flag C++23 code as errors. Keep its flags in step with
  `CXXFLAGS` if you change them.
- **`CPPLINT.cfg` only means something because `cpplint` is in the shell.** A
  config file for a tool nobody runs is decoration; if you drop the tool from
  `devenv.nix`, drop the file too. `linelength` is kept in step with
  `.clang-format`'s `ColumnLimit` and `.editorconfig`'s `max_line_length` — all
  three have to move together.
- **`devenv.lock` is not shipped; `devenv update` writes it and you commit it.**
  Write it early. `devenv.yaml` declares one input, but devenv adds *itself* as
  a second and the lock pins both — until then devenv's own modules float, and
  the environment can change behaviour with no edit by you.
- **For editing `devenv.nix` itself, use `devenv lsp`.** It starts nixd already
  configured for this file, using the nixd bundled inside the devenv binary —
  so there is nothing to add to `packages`, and `devenv lsp --print-config`
  shows what it hands nixd.
