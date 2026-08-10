{
  description = "Node.js REST API template with TypeScript, Express-style middleware and vitest";

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
      nodejs = pkgs.nodejs_24;
    in {
      devShells.default = pkgs.mkShell {
        # npm ships inside the nodejs derivation; pkgs.nodePackages was removed
        # from nixpkgs.
        packages = [nodejs];

        shellHook = ''
          echo "Node.js $(node --version)"
          echo "TypeScript project environment ready!"
        '';
      };
    });
}
