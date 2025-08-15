{
  description = "Node.js + TypeScript Nix template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      nodejs = pkgs.nodejs_20;
    in {
      devShells.default = pkgs.mkShell {
        packages = [
          nodejs
          pkgs.nodePackages.npm
        ];

        shellHook = ''
          echo "Node.js $(node --version)"
          echo "TypeScript project environment ready!"
        '';
      };
    });
}
