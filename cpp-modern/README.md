# C++23 Module Project Template

A modern C++23 project template with named modules, sanitizers, and a fully
reproducible Nix development environment.

## Features

- C++23 named modules via CMake `FILE_SET CXX_MODULES`
- ASan/UBSan enabled in Debug builds
- Ninja Multi-Config — one configure step, switch configs at build time
- GoogleTest + GoogleMock via FetchContent
- clang-format and clang-tidy configured and ready
- Reproducible dev environment via Nix flakes

## Requirements

### Without Nix

- CMake 4.0+
- Ninja
- Clang 21+ (GCC 14+ also works but is less tested with modules)

### With Nix

- [Nix](https://nixos.org/download) with flakes enabled

To enable flakes, add the following to `/etc/nix/nix.conf` or `~/.config/nix/nix.conf`:

```text
experimental-features = nix-command flakes
```

## Getting Started

### With Nix (recommended)

Enter the development shell:

```bash
nix develop
```

This provides Clang 21, CMake 4.x, Ninja, clangd, clang-format, clang-tidy,
lldb, and all other dependencies — no system installation required.

### Without Nix

Ensure CMake, Ninja, and Clang 21+ are installed and on your `$PATH`.

## Building

With Ninja Multi-Config, you configure once and build any configuration without
reconfiguring:

```bash
cmake --preset default
```

Then build whichever configuration you need:

```bash
cmake --build --preset debug         # Debug with ASan/UBSan
cmake --build --preset release       # Optimised release
cmake --build --preset relwithdebinfo # Optimised with debug symbols
```

## Running Tests

```bash
ctest --preset debug
```

Failed tests print their full output automatically.

## Running the Executable

Binaries are placed in a per-config subdirectory under `build/`:

```bash
./build/Debug/my-project
./build/Release/my-project
./build/RelWithDebInfo/my-project
```

## Project Structure

```text
.
├── CMakeLists.txt          # Build definition
├── CMakePresets.json       # Shared build presets
├── CMakeUserPresets.json   # Local overrides (gitignored)
├── flake.nix               # Nix development environment
├── flake.lock              # Pinned Nix dependencies
├── .clang-format           # Formatter configuration
├── .clang-tidy             # Static analysis configuration
├── .clangd                 # clangd LSP configuration
├── src/
│   ├── main.cpp            # Application entry point
│   └── modules/
│       └── my_module.cpp   # C++23 named module (export module my_module;)
└── tests/
    └── main_test.cpp       # GoogleTest test suite
```

## Adding a Module

1. Create a new file under `src/modules/`:

```cpp
// src/modules/my_new_module.cpp
module;
#include <iostream>   // legacy includes go in the global module fragment

export module my_new_module;

export void DoSomething() {
    std::cout << "Hello from my_new_module\n";
}
```

2. Add it to `MODULE_SOURCES` in `CMakeLists.txt`:

```cmake
set(MODULE_SOURCES
    src/modules/my_module.cpp
    src/modules/my_new_module.cpp
)
```

3. Import it where needed:

```cpp
import my_new_module;
```

4. Reconfigure and rebuild:

```bash
cmake --preset default
cmake --build --preset debug
```

## Sanitizers

ASan and UBSan are enabled by default in Debug builds and disabled automatically
in Release and RelWithDebInfo. To disable them entirely:

```bash
cmake --preset default -DUSE_SANITIZERS=OFF
cmake --build --preset debug
```

## Formatting

Format all source files:

```bash
find src tests -name '*.cpp' | xargs clang-format -i
```

## Static Analysis

Run clang-tidy against the project:

```bash
run-clang-tidy -p build src/
```

## LSP / Editor Setup

clangd expects `compile_commands.json` at the project root. Symlink it after
the first configure:

```bash
ln -sf build/compile_commands.json compile_commands.json
```

Or add a `.clangd` file at the project root (already included in this template):

```yaml
CompileFlags:
  CompilationDatabase: build
```

### Neovim

This template works with any LSP-capable Neovim configuration. Ensure clangd
is sourced from the same LLVM version as your compiler to avoid module BMI
version mismatches. If using Nix to manage Neovim, pin clangd to the same
`llvmPackages` version used in `flake.nix`.

### VS Code

Install the [clangd extension](https://marketplace.visualstudio.com/items?itemName=llvm-vs-code-extensions.vscode-clangd).
CMake Tools will auto-detect `CMakePresets.json` and populate the build
configuration picker.

## Local Preset Overrides

Create `CMakeUserPresets.json` (gitignored) to override settings locally
without modifying the shared presets. It inherits from `default` and can
override any cache variable or environment:

```json
{
  "version": 8,
  "configurePresets": [
    {
      "name": "my-local",
      "inherits": "default",
      "environment": {
        "CXX": "/usr/local/bin/clang++-21"
      },
      "cacheVariables": {
        "USE_SANITIZERS": "OFF"
      }
    }
  ],
  "buildPresets": [
    {
      "name": "debug",
      "configurePreset": "my-local",
      "configuration": "Debug"
    }
  ]
}
```

## Known Limitations

- **clangd rename on module symbols** crashes in clangd 21 due to an upstream
  bug. Use search/replace as a workaround when renaming exported symbols.
- **Ninja generator is required** for C++23 module support. The Makefile
  generator does not support module dependency scanning.
- **GoogleTest** is fetched at configure time and requires an internet
  connection on first build. Subsequent builds use the cached download.
