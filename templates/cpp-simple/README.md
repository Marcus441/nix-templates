# cpp-simple

Dev environment for learning C++ with a plain Makefile. The lowest rung of the
C++ ladder: a compiler, a debugger-friendly build, and nothing else to read.

```bash
nix flake init -t 'github:Marcus441/nix-templates#cpp-simple'
git init && git add -A     # flakes see only tracked files
nix develop                # or: direnv allow
```

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

Or build the Nix package, which compiles in a sandbox:

```bash
nix build
nix run         # runs the built binary
```

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
- **`CXX` and `CXXFLAGS` use `?=`,** so the dev shell and the Nix sandbox can
  set the compiler and `make CXXFLAGS=...` still overrides everything. This is
  why the same Makefile works in both places without a conditional.
- **`.clangd` is doing real work here.** With no CMake there is no
  `compile_commands.json`, so without it `clangd` would not know the language
  standard and would flag C++23 code as errors. Keep its flags in step with
  `CXXFLAGS` if you change them.
- **`CPPLINT.cfg` only means something because `cpplint` is in the dev shell.**
  A config file for a tool nobody runs is decoration; if you drop the tool from
  `flake.nix`, drop the file too. `linelength` is kept in step with
  `.clang-format`'s `ColumnLimit` and `.editorconfig`'s `max_line_length` — all
  three have to move together.
- The Nix package overrides `installPhase` because the Makefile has no `install`
  target; stdenv's default would run `make install` and fail.
- `nix fmt` formats `flake.nix` with alejandra.
