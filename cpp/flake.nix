{
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
      project = "project";
    in {
      packages.default = pkgs.stdenv.mkDerivation {
        pname = project;
        version = "0.1.0";
        src = ./.;
        nativeBuildInputs = [pkgs.cmake pkgs.ninja];
        buildInputs = [];
      };

      devShells.default = pkgs.mkShell {
        name = project;
        inputsFrom = [self.packages.${system}.default];
        nativeBuildInputs = with pkgs; [
          clang
          clang-tools
          lldb
          gdb
        ];

        shellHook = ''
          B='\033[1;34m'
          C='\033[0;36m'
          W='\033[1;37m'
          N='\033[0m'

          CLANG_V=$(clang --version | head -n 1 | cut -d' ' -f3)
          CMAKE_V=$(cmake --version | head -n 1 | cut -d' ' -f3)

          echo -e "''${B}╭──────────────────────────────────────────────────╮''${N}"
          echo -e "''${B}│''${N}  ''${W}󱄅  Nix C++ Development Environment  ''${W}󱄅 ''${N}          ''${B}│''${N}"
          echo -e "''${B}├──────────────────────────────────────────────────┤''${N}"
          printf "''${B}│''${N}  ''${C}%-10s''${N} %-35s  ''${B}│''${N}\n" "Compiler:" "clang ''${CLANG_V}"
          printf "''${B}│''${N}  ''${C}%-10s''${N} %-35s  ''${B}│''${N}\n" "CMake:" "''${CMAKE_V}"
          printf "''${B}│''${N}  ''${C}%-10s''${N} %-35s  ''${B}│''${N}\n" "Debugger:" "lldb / gdb"
          echo -e "''${B}╰──────────────────────────────────────────────────╯''${N}"
        '';
      };
    });
}
