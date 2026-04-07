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
      project = "back-prop"; # [META] Match your CMake project name
    in {
      # [BUILD] Standard 'nix build' configuration
      packages.default = pkgs.stdenv.mkDerivation {
        pname = project;
        version = "0.1.0";
        src = ./.;

        # [TOOL] Build-time dependencies
        nativeBuildInputs = with pkgs; [
          cmake
          ninja
          pkg-config
        ];

        # [DEPS] Runtime dependencies (e.g., Eigen, fmt)
        buildInputs = with pkgs; [];

        # [FLAG] Pass flags to CMake
        # Disable sanitizers for the final 'nix build' to maximize performance
        cmakeFlags = [
          "-DCMAKE_BUILD_TYPE=Release"
          "-DUSE_SANITIZERS=OFF"
        ];

        # [TEST] Enables 'nix build' to run CTest automatically
        doCheck = true;
        checkPhase = ''
          ctest --output-on-failure
        '';
      };

      # [DEV] Standard 'nix develop' configuration
      devShells.default = pkgs.mkShell {
        name = "${project}-dev-shell";

        # Inherit inputs from the main package
        inputsFrom = [self.packages.${system}.default];

        # Development-only tools
        nativeBuildInputs = with pkgs; [
          clang_18 # Specific version for C++23/std::print support
          clang-tools_18 # Includes clang-format and clang-tidy
          lldb
          gdb
          valgrind # Useful when ASan is toggled off
        ];

        # [ENV] Hardcode CC/CXX to ensure Nix uses Clang instead of GCC
        shellHook = ''
          export CC=clang
          export CXX=clang++

          # Formatting for the banner
          B='\033[1;34m'; C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'
          CLANG_V=$($CXX --version | head -n 1 | cut -d' ' -f3)
          CMAKE_V=$(cmake --version | head -n 1 | cut -d' ' -f3)

          echo -e "''${B}╭──────────────────────────────────────────────────╮''${N}"
          echo -e "''${B}│''${N}  ''${W}󱄅  Nix C++23 Development Environment  ''${W}󱄅 ''${N}          ''${B}│''${N}"
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
