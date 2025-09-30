{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      devShell = pkgs.mkShell {
        name = "Typst shell";

        buildInputs = with pkgs; [
          typst
        ];

        shellHook = ''
          echo "╔═══════════════════════════════╗"
          echo "║  🖋 Typst Development Shell 🖋  ║"
          echo "╚═══════════════════════════════╝"
          echo "Run 'typst --help' to get started!"
        '';
      };
    });
}
