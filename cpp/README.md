# Project Name

A minimalist C++23 project template, configured for performance and memory safety.

## Features
- **C++23** (via Clang)
- **CMake & Ninja** (with `CMakePresets.json`)
- **GoogleTest** integration
- **Address & Undefined Behavior Sanitizers** (enabled in Debug mode)
- **Nix Flake** for a reproducible hermetic environment

## Prerequisites
- [Nix](https://nixos.org/download.html) (with flakes enabled)
- *Optional but recommended:* [direnv](https://direnv.net/)

## Development Setup

Enter the reproducible development shell:
```bash
nix develop
```
*(If using `direnv`, simply run `direnv allow`)*

## Building

Configure the project using CMake presets:
```bash
cmake --preset default
```

Build the project (Debug by default):
```bash
cmake --build --preset debug
```

For a release build (optimized, no sanitizers):
```bash
cmake --build --preset release
```

## Testing

Run the test suite:
```bash
ctest --preset debug
```
