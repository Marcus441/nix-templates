# cpp-prod-modern

Dev environment for production C++ with modules — `cpp-prod` with the library
exposed as a C++23 named module instead of a header.

```bash
nix flake init -t 'github:Marcus441/nix-templates#cpp-prod-modern'
git init && git add -A
devenv shell               # or: direnv allow
```

## Requirements

**devenv, installed** — https://devenv.sh. There is no `flake.nix` here, so
`nix develop` does not apply. `nix profile install nixpkgs#devenv` is enough.

## What you get

Everything `cpp-prod` has — GoogleTest, ASan/UBSan, TSan and coverage
profiles, warnings-as-errors in the `ci` profile, an install/export set and a
CI workflow — with the library delivered as `import myproject.greeting;`
rather than an installed header.

If you do not specifically want modules, use `cpp-prod`. Module support in the
wider ecosystem is still uneven, and the two limitations below are real.

## Layout

```
src/greeting.cppm       the module interface, in the CXX_MODULES file set
src/greeting_impl.cpp   a module implementation unit, an ordinary source
src/main.cpp            imports the module
tests/greeting_test.cpp imports the module and links the library
```

One library target, `myproject::core`, owns both the module interface and its
implementation unit. That matters: a target holding *only* modules has to be
created conditionally, and every consumer then needs a guard around linking it.
Keeping both halves in one unconditional target removes that class of bug.

## Building

```bash
cmake --workflow --preset dev       # Debug + ASan/UBSan, configure/build/test
cmake --workflow --preset release   # optimized, LTO, hardening
```

`devenv test` does the same from a cold checkout: it builds the environment,
then runs the `release` workflow inside it.

## Testing

```bash
cmake --workflow --preset ci        # warnings as errors
cmake --workflow --preset asan
cmake --workflow --preset tsan
```

GoogleTest comes from the environment.

## Coverage

```bash
cmake --workflow --preset coverage
gcovr --root . --exclude "build/" --gcov-executable "llvm-cov gcov" \
      build/coverage --txt
```

## CI

`.github/workflows/ci.yml` ships with the template so a generated repository
has CI from its first push, and needs no secrets. **It has never run in the
template repository** — GitHub only executes workflows at a repository root.

## Notes

- **`clang-tidy` and modules do not work together, and the `ci` preset leaves
  it off.** `clang-tidy` compiles each translation unit in-process without the
  flags the real compiler driver was given, so it rejects the BMI the build
  just produced: *"signed integer overflow handling differs in precompiled
  file ... configuration mismatch"*. Nothing in this project can fix that — the
  mismatch is between clang-tidy and the compiler driver. `cpp-prod`, which has
  no modules, runs clang-tidy in its `ci` preset normally.
- **Ninja is required, and the generator check is a hard error.** Module
  dependency scanning only works with Ninja; with any other generator configure
  would succeed and then fail deep inside the scanner, which is a much worse
  place to learn about it.
- **`CMAKE_CXX_SCAN_FOR_MODULES` is global and is not a cache variable.** It has
  to be global because every consumer of a module must be scanned too, so the
  generator can order the interface ahead of anything importing it. Caching it
  would leak the setting into subprojects.
- **`clang-tools` in `packages` is load-bearing, not editor convenience.** It
  supplies `clang-scan-deps`, which has to resolve the standard library the
  same way the compiler does; the unwrapped binary does not, and the build
  fails with `fatal error: 'string' file not found` during the scanning step.
  `cpp-prod` ships the same package for `clangd` and `clang-format`; this
  template also cannot build without it.
- **The environment is Clang-only.** For GCC, edit `devenv.nix`: replace
  `pkgs.llvmPackages.clang` with `pkgs.gcc`, `pkgs.llvmPackages.lldb` with
  `pkgs.gdb`, and drop `bintools`.
- **`import std;` is deliberately not used.** It is still behind CMake's
  `CMAKE_EXPERIMENTAL_CXX_IMPORT_STD` gate, whose UUID changes on every CMake
  minor release specifically so projects cannot depend on it. This template
  resolves nixpkgs fresh on first use, so pinning today's UUID would break on
  the next CMake bump with an error pointing at your project rather than at the
  upgrade. It also needs Clang >= 18.1.2 or GCC >= 15, Ninja, and a correct
  `libstdc++.modules.json` from the standard library. If you want it, check
  `Help/dev/experimental.rst` for the CMake version you actually have.
- **The global module fragment is not visible to importers.** `#include`s
  between `module;` and `export module ...;` are private to that unit, which is
  why `greeting_impl.cpp` includes `<string>` again rather than inheriting it.
- **Installing modules exports a `CXX_MODULES_DIRECTORY`.** That is stable
  CMake 3.28, not experimental, but it is the part of this template most likely
  to need attention on a CMake upgrade.
- `find_package` is the dependency path and `FetchContent` is opt-in; see
  `cpp-prod` for the reasoning, which applies here unchanged.
- `.envrc` adds `build/dev` to `PATH`, which is where the `dev` preset puts the
  binary.
- **`devenv.lock` is not shipped; `devenv update` writes it and you commit
  it.** Write it early. `devenv.yaml` declares one input, but devenv adds
  *itself* as a second and the lock pins both — until then devenv's own modules
  float, and the environment can change behaviour with no edit by you.
- **For editing `devenv.nix` itself, use `devenv lsp`.** It starts nixd already
  configured for this file, using the nixd bundled inside the devenv binary —
  so there is nothing to add to `packages`, and `devenv lsp --print-config`
  shows what it hands nixd.
