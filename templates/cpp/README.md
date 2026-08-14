# cpp

Dev environment for C/C++ — C++23 with CMake, build presets and sanitizers, and
no dependency to fetch.

```bash
nix flake init -t 'github:Marcus441/nix-templates#cpp'
git init && git add -A     # flakes see only tracked files
nix develop                # or: direnv allow
```

## What you get

- **C++23** on Clang, with `CMake` and `Ninja` driven by `CMakePresets.json`
- **Address & Undefined Behavior Sanitizers**, on in Debug and off in Release
- **`ctest` with plain assertions** — a test suite with no external dependency
- `clangd`, `clang-format`, `clang-tidy`, `cpplint` and `lldb`

This is the middle rung of the C++ ladder. Below it, `cpp-simple` is a compiler
and a Makefile and nothing else. Above it, `cpp-prod` adds GoogleTest, a
library/executable split, TSan and coverage profiles, an install/export set and
a CI workflow; `cpp-prod-modern` adds C++23 modules on top of that.

## Layout

`src/greeting.cpp` holds the logic, `src/main.cpp` is the program, and
`tests/main_test.cpp` is a second program that checks the same code. Both
executables compile `src/greeting.cpp` directly — a test binary is just another
executable. Promoting the shared code to a library target is what `cpp-prod`
does.

## Building

With CMake presets, inside the dev shell:

```bash
cmake --preset default
cmake --build --preset debug        # Debug, sanitizers on
cmake --build --preset release      # optimized, no sanitizers
```

Or build the Nix package, which compiles in a sandbox and runs the tests:

```bash
nix build
nix run                             # runs the built binary
```

## Testing

```bash
ctest --preset debug                # under ASan/UBSan
ctest --preset release
```

`nix build` runs the same suite in its check phase.

## Linting

```bash
clang-format -i src/*.cpp include/*.hpp
clang-tidy -p build src/*.cpp
cpplint src/*.cpp include/*.hpp
```

## Notes

- **The tests `#undef NDEBUG` before including `<cassert>`.** A Release build
  defines `NDEBUG`, which compiles `assert()` away entirely — without that line
  the suite would pass in Release without executing a single check, which is a
  quiet way to ship a broken test suite. Any assertion-based test needs it.
- **`-fno-sanitize-recover=all` is what makes the sanitizers fail a test.** By
  default UBSan prints a diagnostic and the process still exits 0, so `ctest`
  reports success on code that just tripped the sanitizer. ASan aborts either
  way; UBSan does not.
- **The sanitizers are wired to the `Debug` configuration, not to a preset.**
  That keeps this template short, but it also means ASan/UBSan and TSan cannot
  both be expressed — they are mutually exclusive and there is only one Debug
  config to hang them on. `cpp-prod` uses a cache variable and one build tree
  per profile instead, which is what you want as soon as you need TSan.
- **The Clang toolchain is `pkgs.llvmPackages`, the version nixpkgs defaults to
  on your platform**, rather than a pinned one. That is the version nixpkgs
  actually builds and caches everywhere, so the dev shell comes from the binary
  cache instead of compiling a compiler. Pin it if you need to:

  ```nix
  pkgs.llvmPackages_21.stdenv
  ```

  Be aware of what pinning costs on macOS. The darwin stdenv tracks a recent
  libc++ and Apple SDK, and an older LLVM's `compiler-rt` does not always
  compile against them — pinning LLVM 18 here used to make `nix develop` build
  LLVM from source and then fail outright on `aarch64-darwin`. If you pin,
  check it on every platform your `systems` list claims.
- `CPPLINT.cfg` only means something because `cpplint` is in the dev shell; its
  `linelength` is kept in step with `.clang-format`'s `ColumnLimit` and
  `.editorconfig`'s `max_line_length`.
- `.envrc` adds `build/Debug` to `PATH`. The `Ninja Multi-Config` generator
  writes each configuration to its own subdirectory, so the binary is at
  `build/Debug/myproject`, not `build/myproject` — add `build/Release` too if
  you want to run optimized builds by bare name.
- `nix fmt` formats `flake.nix` with alejandra.
