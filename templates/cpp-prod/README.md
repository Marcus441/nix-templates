# cpp-prod

devenv environment for production C/C++ — C++23 on Clang, a library/executable
split, GoogleTest, one build tree per sanitizer profile, and a CI workflow.

```bash
nix flake init -t 'github:Marcus441/nix-templates#cpp-prod'
git init && git add -A
devenv shell               # or: direnv allow
```

## Requirements

**devenv, installed** — https://devenv.sh. There is no `flake.nix` here, so
`nix develop` does not apply. `nix profile install nixpkgs#devenv` is enough.

## What you get

- **C++23** on the Clang toolchain — GCC is a three-line edit, see Notes
- **GoogleTest and GoogleMock**, resolved with `find_package`, never fetched
- **ASan/UBSan, TSan and coverage profiles**, each in its own build tree
- **Warnings as errors and `clang-tidy` in the `ci` profile only**, so an
  upstream compiler bump cannot break `devenv test`
- **An install/export set**, so `find_package(myproject)` works downstream
- `clangd`, `clang-format`, `clang-tidy`, `cpplint`, `gcovr` and `lldb`
- **A GitHub Actions workflow** in `.github/workflows/ci.yml`

## Layout

```
include/myproject/greeting.hpp   public headers, installed
src/greeting.cpp                 the library, myproject::core
src/main.cpp                     a thin executable over the library
tests/greeting_test.cpp          links the library, not the sources
cmake/myproject-config.cmake.in  package config for downstream consumers
```

The logic lives in a library so the tests link the same artifact the program
does. That split is the main thing separating this template from `cpp`, where
both executables just compile the same source file.

## Building

Each profile gets its own build tree under `build/`, so they coexist without
reconfiguring:

```bash
cmake --workflow --preset dev       # Debug + ASan/UBSan, configure/build/test
cmake --workflow --preset release   # optimized, LTO, hardening
```

Or step by step:

```bash
cmake --preset dev
cmake --build --preset dev
ctest --preset dev
```

The build-shaped command is `devenv test`, which builds the environment and
then runs the `release` workflow preset — configure, the optimized, hardened,
LTO build, then ctest:

```bash
devenv test
```

## Testing

```bash
cmake --workflow --preset ci        # warnings as errors + clang-tidy
cmake --workflow --preset asan      # optimized ASan/UBSan
cmake --workflow --preset tsan      # ThreadSanitizer
```

GoogleTest comes from the environment. `devenv test` runs the same suite via
the `release` preset, in Release with sanitizers off.

## Coverage

```bash
cmake --workflow --preset coverage
gcovr --root . --exclude "build/" --gcov-executable "llvm-cov gcov" \
      build/coverage --txt
```

Clang emits gcov-format `.gcno`/`.gcda` data; `--gcov-executable` points
`gcovr` at the reader that matches it. Add `--html-details
coverage/index.html` for a browsable report. `--exclude` keeps CMake's
compiler-probe source out of the numbers.

## CI

`.github/workflows/ci.yml` ships with the template so a generated repository
has CI from its first push. It runs `devenv test` on Linux and macOS, the
`ci`/`asan`/`tsan` profiles in the shell, and a `clang-format` check. It needs
no secrets.

**It has never run in the template repository** — GitHub only executes
workflows found at a repository root, and there it sits inside a template
directory. Treat the first run in your own repo as its first real test.

The `aarch64-linux` leg is left out on purpose: `ubuntu-24.04-arm` runners are
free for public repositories only. Add it to the `devenv` job's matrix if that
suits your repository.

## Notes

- **GCC instead of Clang is an edit to `devenv.nix`.** Replace
  `pkgs.llvmPackages.clang` with `pkgs.gcc`, `pkgs.llvmPackages.lldb` with
  `pkgs.gdb`, and drop `pkgs.llvmPackages.bintools`. `clang-tools` stays:
  `clangd`, `clang-format` and `clang-tidy` work regardless of the compiler.
- **`-Werror` is not in `CMakeLists.txt`.** It is
  `CMAKE_COMPILE_WARNING_AS_ERROR`, off by default and on only in the `ci` and
  `asan` presets. This template resolves nixpkgs fresh on first use, so a new
  compiler adding a warning to `-Wextra` would otherwise break `devenv test`
  with no change on your side. The built-in also gives you
  `cmake --build --compile-no-warning-as-error` as an escape hatch, which a
  hand-rolled `-Werror` does not.
- **`find_package` is the dependency path; `FetchContent` is opt-in.** The
  environment provides GoogleTest, so configure takes the `find_package`
  branch and no build reaches the network. If GoogleTest is missing, the
  configure step fails with a message naming `-DMYPROJECT_FETCH_DEPENDENCIES=ON`
  rather than silently downloading.
- **The hardening flags emit `-U` before `-D`.** A Nix cc-wrapper already
  defines `_FORTIFY_SOURCE` and `_LIBCPP_HARDENING_MODE`, and redefining a
  macro to a different value is `-Wmacro-redefined` — harmless until the `ci`
  preset turns warnings into errors, at which point it is a build failure. The
  libc++/libstdc++ choice is detected from the standard library, not the
  compiler: Clang uses libstdc++ on Linux and libc++ on macOS.
- **`-fno-sanitize-recover=all` is what makes a sanitizer failure fail a test.**
  By default UBSan prints a diagnostic and the process still exits 0. It is not
  applied to TSan, which has no recovery mode — `TSAN_OPTIONS=halt_on_error=1`
  in the test preset does that job instead.
- **Sanitizers are applied at directory scope**, not per target, because they
  must instrument every translation unit in the build to avoid false positives
  at a boundary. `MYPROJECT_SANITIZERS` is a cache variable holding a semicolon
  list, and combining `thread` with `address` is a configure-time error.
- **No `detect_leaks=1` anywhere.** ASan already enables LeakSanitizer by
  default on Linux, and on macOS setting it can abort the process at startup.
- **`MYPROJECT_ENABLE_IPO` defaults off.** `check_ipo_supported` compiles a
  trivial program and can succeed where a real link fails, so LTO is exercised
  by the `release` preset — the one `devenv test` runs — rather than by the
  default build.
- **The interface targets appear in `install(TARGETS)`.** Linking
  `myproject::warnings` privately into a static library still records it as a
  `$<LINK_ONLY:...>` usage requirement, and `install(EXPORT)` refuses to export
  a target naming one it does not have. Their flags are wrapped in
  `$<BUILD_INTERFACE:...>`, so a downstream consumer inherits none of them.
- **`devenv.lock` is not shipped; `devenv update` writes it and you commit
  it.** Write it early. `devenv.yaml` declares one input, but devenv adds
  *itself* as a second and the lock pins both — until then devenv's own
  modules float, and the environment can change behaviour with no edit by you
  and no release you asked for.
- **For editing `devenv.nix` itself, use `devenv lsp`.** It starts nixd already
  configured for this file, using the nixd bundled inside the devenv binary —
  so there is nothing to add to `packages`, and `devenv lsp --print-config`
  shows what it hands nixd.
- `CPPLINT.cfg` only means something because `cpplint` is in the environment;
  its `linelength` is kept in step with `.clang-format` and `.editorconfig`.
- `.envrc` adds `build/dev` to `PATH`, which is where the `dev` preset puts the
  binary.
- **There is no `nix fmt` here.** A flake template gets a `formatter` output;
  this one has no flake to hang it on. `clang-format` covers the sources, and
  devenv can run git hooks — see
  [devenv.sh/git-hooks](https://devenv.sh/git-hooks/).
