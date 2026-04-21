{
  description = "A high-performance C++23 development template";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      # [META] Project and tooling versions
      project = "myproject";
      llvm_ver = "21";
      llvm_pkgs = pkgs."llvmPackages_${llvm_ver}";
    in {
      # [PACK] Standard package build using GCC — Clang + modules in the Nix
      # sandbox is blocked by nixpkgs bug #452260 (clang-scan-deps bypasses
      # the clang wrapper and cannot find system headers). GCC is used here
      # as a reliable CI correctness gate. The dev shell uses Clang 21.
      packages.default = pkgs.stdenv.mkDerivation {
        pname = project;
        version = "0.1.0";
        src = pkgs.lib.cleanSource ./.;
        # [TOOL] Build-time host dependencies
        nativeBuildInputs = with pkgs; [
          cmake
          ninja
          pkg-config
        ];
        # [DEPS] Target runtime dependencies
        buildInputs = with pkgs; [
          gtest
        ];
        # [FLAG] CMake configuration flags
        cmakeFlags = [
          "-DCMAKE_BUILD_TYPE=Release"
          "-DUSE_SANITIZERS=OFF"
          "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
          "-DCMAKE_THREAD_LIBS_INIT=-lpthread"
          "-DCMAKE_USE_PTHREADS_INIT=1"
        ];
        # [TEST] Validation logic
        doCheck = true;
        checkPhase = ''
          ctest --test-dir . --build-config Release --output-on-failure
        '';
      };
      # [SHELL] Development environment — Clang 21 with full module support
      devShells.default = pkgs.mkShell {
        name = "${project}-dev-shell";
        # [INPT] Inherit build requirements
        inputsFrom = [self.packages.${system}.default];
        # [TOOL] Development-only utilities
        nativeBuildInputs = with pkgs;
          [
            llvm_pkgs.clang-tools
            llvm_pkgs.lldb
          ]
          ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            gdb
            valgrind
          ];
        # [HOOK] Shell entry configuration
        shellHook = ''
          export CC=${llvm_pkgs.clang}/bin/clang
          export CXX=${llvm_pkgs.clang}/bin/clang++
          B='\033[1;34m'; C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'
          CLANG_V=$($CXX --version | head -n 1 | cut -d' ' -f3)
          CMAKE_V=$(cmake --version | head -n 1 | cut -d' ' -f3)
          echo -e "''${B}╭──────────────────────────────────────────────────╮''${N}"
          echo -e "''${B}│''${N}  ''${W}󱄅  Nix C++23 Development Environment ''${W}󱄅 ''${N}         ''${B}│''${N}"
          echo -e "''${B}├──────────────────────────────────────────────────┤''${N}"
          printf "''${B}│''${N}  ''${C}%-10s''${N} %-35s  ''${B}│''${N}\n" "Compiler:" "Clang ''${CLANG_V}"
          printf "''${B}│''${N}  ''${C}%-10s''${N} %-35s  ''${B}│''${N}\n" "Standard:" "C++23"
          printf "''${B}│''${N}  ''${C}%-10s''${N} %-35s  ''${B}│''${N}\n" "CMake:" "''${CMAKE_V} (Ninja)"
          printf "''${B}│''${N}  ''${C}%-10s''${N} %-35s  ''${B}│''${N}\n" "Tools:" "tidy, format, asan, ubsan"
          echo -e "''${B}╰──────────────────────────────────────────────────╯''${N}"
        '';
      };
    });
}
