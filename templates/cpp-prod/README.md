# cpp-prod

Dev environment for production C/C++ — C++23, a library/executable split,
GoogleTest, one build tree per sanitizer profile, and a CI workflow.

```bash
nix flake init -t 'github:Marcus441/nix-templates#cpp-prod'
git init && git add -A     # flakes see only tracked files
nix develop                # or: direnv allow
```

## What you get

- **C++23** with interchangeable **Clang / GCC** toolchains, Clang by default
- **GoogleTest and GoogleMock**, resolved with `find_package`, never fetched
- **ASan/UBSan, TSan and coverage profiles**, each in its own build tree
- **Warnings as errors and `clang-tidy` in the `ci` profile only**, so an
  upstream compiler bump cannot break `nix build`
- **An install/export set**, so `find_package(myproject)` works downstream
- `clangd`, `clang-format`, `clang-tidy`, `cpplint`, `gcovr`, and a debugger
  matching the compiler (`lldb` for Clang, `gdb` for GCC)
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

Or build the Nix package, which compiles in a sandbox and runs the tests:

```bash
nix build           # Clang
nix build '.#gcc'   # GCC
nix run             # runs the built binary
```

## Testing

```bash
cmake --workflow --preset ci        # warnings as errors + clang-tidy
cmake --workflow --preset asan      # optimized ASan/UBSan
cmake --workflow --preset tsan      # ThreadSanitizer
```

`nix build` runs the same suite in its check phase, in Release with sanitizers
off.

## Coverage

```bash
cmake --workflow --preset coverage
gcovr --root . --exclude "build/" --gcov-executable "llvm-cov gcov" \
      build/coverage --txt
```

Both compilers emit the same `.gcno`/`.gcda` data; only the reader differs. The
command above is for the default Clang shell. Under `nix develop '.#gcc'`, drop
the `--gcov-executable` flag so `gcovr` uses GCC's own `gcov`:

```bash
gcovr --root . --exclude "build/" build/coverage --txt
```

Add `--html-details coverage/index.html` for a browsable report. `--exclude`
keeps CMake's compiler-probe source out of the numbers.

## CI

`.github/workflows/ci.yml` ships with the template so a generated repository
has CI from its first push. It runs `nix build` on Linux and macOS, the GCC
build on Linux, the `ci`/`asan`/`tsan` profiles in the dev shell, and a
`clang-format` check. It needs no secrets.

**It has never run in the template repository** — GitHub only executes
workflows found at a repository root, and there it sits inside a template
directory. Treat the first run in your own repo as its first real test.

The `aarch64-linux` leg is left out on purpose: `ubuntu-24.04-arm` runners are
free for public repositories only. Add it to the `nix` job's matrix if that
suits your repository.

## Notes

- **`-Werror` is not in `CMakeLists.txt`.** It is
  `CMAKE_COMPILE_WARNING_AS_ERROR`, off by default and on only in the `ci` and
  `asan` presets. This template resolves nixpkgs fresh on first use, so a new
  compiler adding a warning to `-Wextra` would otherwise break `nix build` with
  no change on your side. The built-in also gives you
  `cmake --build --compile-no-warning-as-error` as an escape hatch, which a
  hand-rolled `-Werror` does not.
- **`find_package` is the dependency path; `FetchContent` is opt-in.** The dev
  shell and the Nix sandbox both provide GoogleTest, so both take the same
  branch and no build reaches the network. If GoogleTest is missing, the
  configure step fails with a message naming
  `-DMYPROJECT_FETCH_DEPENDENCIES=ON` rather than silently downloading. This is
  the opposite of what `cpp` used to do, and it is why no
  `-DFETCHCONTENT_FULLY_DISCONNECTED=ON` appears in `flake.nix`.
- **GoogleTest reaches the dev shell through `checkInputs`.** That works only
  because `doCheck = true` promotes check inputs into the build inputs. If you
  ever set `doCheck = false`, `cmake --preset dev` in the shell starts failing
  to find GoogleTest.
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
  by the `release` preset rather than by the default build.
- **The interface targets appear in `install(TARGETS)`.** Linking
  `myproject::warnings` privately into a static library still records it as a
  `$<LINK_ONLY:...>` usage requirement, and `install(EXPORT)` refuses to export
  a target naming one it does not have. Their flags are wrapped in
  `$<BUILD_INTERFACE:...>`, so a downstream consumer inherits none of them.
- `CPPLINT.cfg` only means something because `cpplint` is in the dev shell; its
  `linelength` is kept in step with `.clang-format` and `.editorconfig`.
- `.envrc` adds `build/dev` to `PATH`, which is where the `dev` preset puts the
  binary.
- `nix fmt` formats `flake.nix` with alejandra.
