# cpp

Dev environment for C/C++ — C++23, configured for performance and memory safety.

```bash
nix flake init -t github:Marcus441/nix-templates#cpp
git init && git add -A     # flakes see only tracked files
nix develop                # or: direnv allow
```

## What you get

- **C++23** with interchangeable **Clang / GCC** toolchains, Clang by default
- **CMake & Ninja**, with `CMakePresets.json`
- **GoogleTest**, wired in without a network fetch
- **Address & Undefined Behavior Sanitizers**, enabled in Debug
- `clangd`, `clang-format` and `clang-tidy` in both shells; the debugger matches
  the compiler (`lldb` for Clang, `gdb` for GCC)

The two toolchains are interchangeable because the compiler comes from the
stdenv, so both keep the platform-default C++ standard library — libstdc++ on
Linux. Only the compiler driver differs, and `CC`/`CXX` are set by the shell, so
the same CMake presets work in both:

```bash
nix develop .#clang
nix develop .#gcc
```

## Building

With CMake presets, inside the dev shell:

```bash
cmake --preset default
cmake --build --preset debug        # Debug, sanitizers on
cmake --build --preset release      # optimized, no sanitizers
```

Or build the Nix package, which compiles in a sandbox and runs the tests. The
package builds follow the same toolchain scheme, `clang` being the default:

```bash
nix build           # Clang
nix build .#gcc     # GCC
nix run             # runs the built binary
```

## Testing

```bash
ctest --preset debug
```

`nix build` runs the same suite in its check phase.

## Notes

- **The Clang toolchain is `pkgs.llvmPackages`, the version nixpkgs defaults to
  on your platform** — currently LLVM 21 — rather than a pinned one. That is
  the version nixpkgs actually builds and caches everywhere, so the dev shell
  comes from the binary cache instead of compiling a compiler. Pin it if you
  need to:

  ```nix
  llvm = pkgs.llvmPackages_21;
  ```

  Be aware of what pinning costs on macOS. The darwin stdenv tracks a recent
  libc++ and Apple SDK, and an older LLVM's `compiler-rt` does not always
  compile against them — pinning LLVM 18 here used to make `nix develop` build
  LLVM from source and then fail outright on `aarch64-darwin`. If you pin,
  check it on every platform your `systems` list claims.
- **GoogleTest comes from `checkInputs`, not `FetchContent`.** A Nix build
  sandbox has no network, so `-DFETCHCONTENT_FULLY_DISCONNECTED=ON` is passed
  and `CMakeLists.txt` takes its disconnected branch. If you add a dependency,
  add it the same way rather than reaching for `FetchContent` — otherwise
  `nix build` fails while a local `cmake` still works, which is a confusing way
  to find out.
- `meta.mainProgram` names the binary CMake produces (`my-project`), not
  `pname`. Change both if you rename the project.
- `.envrc` adds `build` to `PATH`, which is where the presets put the binary.
- `nix fmt` formats `flake.nix` with alejandra.
